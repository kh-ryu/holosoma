# Exit on error, and print commands
set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$(dirname "$SCRIPT_DIR")

echo "Setting up inference environment"

OS=$(uname -s)
ARCH=$(uname -m)

case $ARCH in
  "aarch64"|"arm64") ARCH="aarch64" ;;
  "x86_64") ARCH="x86_64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case $OS in
  "Linux")
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh"
    ;;
  "Darwin")
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
    INSTALL_CMD="brew install"
    ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Create overall workspace
source ${SCRIPT_DIR}/source_common.sh
ENV_ROOT=$CONDA_ROOT/envs/hsinference

SENTINEL_FILE=${WORKSPACE_DIR}/.env_setup_finished_inference

mkdir -p $WORKSPACE_DIR

if [[ ! -f $SENTINEL_FILE ]]; then
  PIN_INSTALL_STRATEGY=${PIN_INSTALL_STRATEGY:-auto}
  PINOCCIO_CONDA_TIMEOUT_SEC=${PINOCCIO_CONDA_TIMEOUT_SEC:-600}

  case "$PIN_INSTALL_STRATEGY" in
    auto|pip|conda) ;;
    *)
      echo "Invalid PIN_INSTALL_STRATEGY: $PIN_INSTALL_STRATEGY"
      echo "Allowed values: auto, pip, conda"
      exit 1
      ;;
  esac

  verify_pinocchio_import() {
    python -c "import pinocchio as pin; print(f'pinocchio version: {pin.__version__}')"
  }

  run_conda_pinocchio_install() {
    if command -v timeout >/dev/null 2>&1; then
      timeout "${PINOCCIO_CONDA_TIMEOUT_SEC}s" run_conda install -n hsinference pinocchio -y -c conda-forge --override-channels
    else
      run_conda install -n hsinference pinocchio -y -c conda-forge --override-channels
    fi
  }

  install_pinocchio_with_strategy() {
    echo "Pinocchio install strategy: ${PIN_INSTALL_STRATEGY}"
    echo "Pinocchio conda timeout (seconds): ${PINOCCIO_CONDA_TIMEOUT_SEC}"

    case "$PIN_INSTALL_STRATEGY" in
      pip)
        pip install "pin>=3.8.0"
        verify_pinocchio_import
        ;;
      conda)
        run_conda_pinocchio_install
        verify_pinocchio_import
        ;;
      auto)
        local conda_ok=0
        if run_conda_pinocchio_install; then
          conda_ok=1
        fi

        if [[ $conda_ok -eq 0 ]]; then
          echo "Warning: conda install for pinocchio timed out or failed; falling back to pip install pin>=3.8.0"
          pip install "pin>=3.8.0"
        fi

        verify_pinocchio_import
        ;;
    esac
  }

  # Install miniconda
  if [[ ! -d $CONDA_ROOT ]]; then
    mkdir -p $CONDA_ROOT
    curl $MINICONDA_URL -o $CONDA_ROOT/miniconda.sh
    bash $CONDA_ROOT/miniconda.sh -b -u -p $CONDA_ROOT
    rm $CONDA_ROOT/miniconda.sh
  fi

  run_conda() {
    # Avoid libmamba/libstdc++ compatibility issues on older system toolchains.
    LD_LIBRARY_PATH="$CONDA_ROOT/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    CONDA_SOLVER=classic \
    CONDA_NO_PLUGINS=true \
    "$CONDA_ROOT/bin/conda" --no-plugins "$@"
  }

  # Create the conda environment
  if [[ ! -d $ENV_ROOT ]]; then
    run_conda create -y -n hsinference python=3.10 -c conda-forge --override-channels
  fi

  # Install swig without sudo on Linux by using conda packages.
  if ! command -v swig >/dev/null 2>&1; then
    if [[ $OS == "Linux" ]]; then
      run_conda install -n hsinference -c conda-forge -y swig --override-channels
    elif [[ $OS == "Darwin" ]]; then
      # Install brew if needed
      if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo >> $HOME/.zprofile
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      $INSTALL_CMD swig
    fi
  fi

  source $CONDA_ROOT/bin/activate hsinference

  # Install libstdcxx-ng to fix the error: `version `GLIBCXX_3.4.32' not found` on Ubuntu 24.04
  # Only needed on Linux (not macOS)
  if [[ $OS == "Linux" ]]; then
    run_conda install -n hsinference -c conda-forge -y libstdcxx-ng --override-channels
  fi

  # Install holosoma_inference
  # Note: On macOS, only Unitree SDK is supported (Booster SDK is Linux-only)
  if [[ $OS == "Darwin" ]]; then
    echo "Note: Installing Unitree SDK only (Booster SDK is not supported on macOS)"
    pip install -e $ROOT_DIR/src/holosoma_inference[unitree]
  else
    pip install -e $ROOT_DIR/src/holosoma_inference[unitree,booster]
  fi
  # Setup a few things for ARM64 Linux (G1 Jetson)
  # Otherwise we get this error:
  # /opt/rh/gcc-toolset-14/root/usr/include/c++/14/bits/stl_vector.h:1130: ...
  if [[ $OS == "Linux" && $ARCH == "aarch64" ]]; then
    if command -v nvpmodel >/dev/null 2>&1; then
      nvpmodel -m 0 2>/dev/null || true
    fi
    pip install pin>=3.8.0
    verify_pinocchio_import
  else
    if [[ ! -d $WORKSPACE_DIR/unitree_sdk2_python ]]; then
      git clone https://github.com/unitreerobotics/unitree_sdk2_python.git $WORKSPACE_DIR/unitree_sdk2_python
    fi
    pip install -e $WORKSPACE_DIR/unitree_sdk2_python/
    install_pinocchio_with_strategy
  fi

  cd $ROOT_DIR
  touch $SENTINEL_FILE
fi
