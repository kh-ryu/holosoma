#!/bin/bash
# Detect script directory (works in both bash and zsh)
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
elif [ -n "${ZSH_VERSION}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )
fi

# Use MUJOCO_CONDA_ENV_NAME if provided, then CONDA_ENV_NAME, otherwise default to "hsmujoco"
MUJOCO_CONDA_ENV_NAME=${MUJOCO_CONDA_ENV_NAME:-${CONDA_ENV_NAME:-hsmujoco}}
echo "conda environment name is set to: $MUJOCO_CONDA_ENV_NAME"

source ${SCRIPT_DIR}/source_common.sh
activate_conda_env "$MUJOCO_CONDA_ENV_NAME" || { return 1 2>/dev/null || exit 1; }

# Set MuJoCo-specific environment variables
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CONDA_ROOT}/envs/$MUJOCO_CONDA_ENV_NAME/lib

# Default to EGL on headless servers unless MUJOCO_GL is already set by user.
if [ -z "${DISPLAY:-}" ] && [ -z "${MUJOCO_GL:-}" ]; then
    export MUJOCO_GL=egl
    echo "DISPLAY is not set. Defaulting MUJOCO_GL=egl for headless MuJoCo rendering."
fi

# Validate environment is properly activated
if python -c "import mujoco" 2>/dev/null; then
    echo "MuJoCo environment activated successfully"
    echo "MuJoCo version: $(python -c 'import mujoco; print(mujoco.__version__)')"
    echo "PyTorch version: $(python -c 'import torch; print(torch.__version__)')"

    # Print mujoco-warp commit if installed
    if python -c "import mujoco_warp" 2>/dev/null; then
        MUJOCO_WARP_COMMIT=$(git -C ${WORKSPACE_DIR}/mujoco_warp rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo "MuJoCo Warp commit: ${MUJOCO_WARP_COMMIT}"
    fi
else
    echo "Warning: MuJoCo environment activation may have issues"
fi
