# Detect script directory (works in both bash and zsh)
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
elif [ -n "${ZSH_VERSION}" ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )
fi
source ${SCRIPT_DIR}/source_common.sh
activate_conda_env "hsinference" || { return 1 2>/dev/null || exit 1; }
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CONDA_ROOT}/envs/hsinference/lib/python3.10/site-packages/lib

# Check UFW status if ufw command exists
if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q "Status: inactive"; then
        echo "✓ UFW disabled"
    else
        echo "Warning: UFW may be enabled (or status unavailable without elevated privileges)."
    fi
fi
