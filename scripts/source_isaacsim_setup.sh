# Detect script directory (works in both bash and zsh)
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
elif [ -n "${ZSH_VERSION}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )
fi

# Use ISAACSIM_CONDA_ENV_NAME if provided, then CONDA_ENV_NAME, otherwise default to "hssim"
ISAACSIM_CONDA_ENV_NAME=${ISAACSIM_CONDA_ENV_NAME:-${CONDA_ENV_NAME:-hssim}}
echo "conda environment name is set to: $ISAACSIM_CONDA_ENV_NAME"

source ${SCRIPT_DIR}/source_common.sh
activate_conda_env "$ISAACSIM_CONDA_ENV_NAME" || { return 1 2>/dev/null || exit 1; }
export OMNI_KIT_ACCEPT_EULA=1
