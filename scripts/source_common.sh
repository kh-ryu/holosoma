WORKSPACE_DIR=$HOME/.holosoma_deps
CONDA_ROOT=$WORKSPACE_DIR/miniconda3

activate_conda_env() {
    local conda_env_name="$1"
    if [ -z "${conda_env_name}" ]; then
        echo "Error: conda environment name is required"
        return 1
    fi
    if [ ! -f "${CONDA_ROOT}/bin/activate" ]; then
        echo "Error: conda activate script not found at ${CONDA_ROOT}/bin/activate"
        return 1
    fi

    local prev_conda_solver_set=0
    local prev_conda_no_plugins_set=0
    local prev_conda_solver=""
    local prev_conda_no_plugins=""

    if [ "${CONDA_SOLVER+x}" = "x" ]; then
        prev_conda_solver_set=1
        prev_conda_solver="$CONDA_SOLVER"
    fi
    if [ "${CONDA_NO_PLUGINS+x}" = "x" ]; then
        prev_conda_no_plugins_set=1
        prev_conda_no_plugins="$CONDA_NO_PLUGINS"
    fi

    # Avoid libmamba/libstdc++ compatibility issues during activation on older host toolchains.
    case ":${LD_LIBRARY_PATH:-}:" in
        *":${CONDA_ROOT}/lib:"*) ;;
        *) export LD_LIBRARY_PATH="${CONDA_ROOT}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ;;
    esac
    export CONDA_SOLVER=classic
    export CONDA_NO_PLUGINS=true
    source "${CONDA_ROOT}/bin/activate" "${conda_env_name}"
    local activate_status=$?
    if [ "$activate_status" -eq 0 ] && [ "${CONDA_DEFAULT_ENV:-}" != "${conda_env_name}" ]; then
        echo "Error: failed to activate conda environment '${conda_env_name}'"
        activate_status=1
    fi

    if [ "$prev_conda_solver_set" -eq 1 ]; then
        export CONDA_SOLVER="$prev_conda_solver"
    else
        unset CONDA_SOLVER
    fi
    if [ "$prev_conda_no_plugins_set" -eq 1 ]; then
        export CONDA_NO_PLUGINS="$prev_conda_no_plugins"
    else
        unset CONDA_NO_PLUGINS
    fi

    return $activate_status
}
