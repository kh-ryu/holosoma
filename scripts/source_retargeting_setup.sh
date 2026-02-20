# Detect script directory (works in both bash and zsh)
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
elif [ -n "${ZSH_VERSION}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )
fi

RETARGETING_CONDA_ENV_NAME=${RETARGETING_CONDA_ENV_NAME:-${CONDA_ENV_NAME:-hsretargeting}}
echo "conda environment name is set to: $RETARGETING_CONDA_ENV_NAME"

source ${SCRIPT_DIR}/source_common.sh
activate_conda_env "$RETARGETING_CONDA_ENV_NAME" || { return 1 2>/dev/null || exit 1; }
