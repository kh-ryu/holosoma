#!/bin/bash

# Script for running retargeting, data conversion, and whole-body tracking training
# Requires Ubuntu/Linux OS (IsaacSim is not supported on Mac)

set -e  # Exit on error

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RETARGETING_DIR="$PROJECT_ROOT/src/holosoma_retargeting/holosoma_retargeting"

if [ ! -d "$RETARGETING_DIR" ]; then
    echo "Error: retargeting directory not found at $RETARGETING_DIR"
    exit 1
fi

# Detect operating system and check if it's supported
OS="$(uname -s)"
case "${OS}" in
    Linux*)
        MACHINE=Linux
        echo "Detected Linux OS - proceeding..."
        ;;
    Darwin*)
        echo "Error: Mac OS is not supported. This script requires Ubuntu/Linux for IsaacSim."
        exit 1
        ;;
    CYGWIN*|MINGW*)
        echo "Error: Windows is not supported. This script requires Ubuntu/Linux for IsaacSim."
        exit 1
        ;;
    *)
        echo "Error: Unsupported operating system: ${OS}. This script requires Ubuntu/Linux for IsaacSim."
        exit 1
        ;;
esac

# Source retargeting setup script (for retargeting and data conversion)
echo "Sourcing retargeting setup..."
RETARGETING_CONDA_ENV_NAME="${RETARGETING_CONDA_ENV_NAME:-hsretargeting}" \
    source "$PROJECT_ROOT/scripts/source_retargeting_setup.sh"

# Change to retargeting directory
cd "$RETARGETING_DIR"

# Step 0: Download and process LAFAN data if needed
echo "Checking LAFAN data availability..."
LAFAN_DATA_DIR="$RETARGETING_DIR/demo_data/lafan"
LAFAN_TEMP_DIR="$RETARGETING_DIR/demo_data/lafan_temp"
LAFAN_ZIP="$RETARGETING_DIR/demo_data/lafan1.zip"
DATA_UTILS_DIR="$RETARGETING_DIR/data_utils"

# Check if processed LAFAN data already exists
if [ -d "$LAFAN_DATA_DIR" ] && compgen -G "$LAFAN_DATA_DIR/*.npy" > /dev/null; then
    echo "LAFAN data already processed. Skipping download and processing."
else
    echo "LAFAN data not found. Downloading and processing..."

    # Create demo_data directory if it doesn't exist
    mkdir -p "$RETARGETING_DIR/demo_data"

    # Download lafan1.zip if it doesn't exist
    if [ ! -f "$LAFAN_ZIP" ]; then
        echo "Downloading lafan1.zip..."
        curl -L -o "$LAFAN_ZIP" "https://github.com/ubisoft/ubisoft-laforge-animation-dataset/raw/master/lafan1/lafan1.zip"
    else
        echo "lafan1.zip already exists. Skipping download."
    fi

    # Uncompress lafan1.zip to temp directory
    if [ ! -d "$LAFAN_TEMP_DIR" ] || ! compgen -G "$LAFAN_TEMP_DIR/*.bvh" > /dev/null; then
        echo "Uncompressing lafan1.zip..."
        mkdir -p "$LAFAN_TEMP_DIR"
        unzip -q -o "$LAFAN_ZIP" -d "$LAFAN_TEMP_DIR"
        # Handle different zip structures - move BVH files to top level
        if [ -d "$LAFAN_TEMP_DIR/lafan1/lafan" ]; then
            # Structure: lafan1/lafan/*.bvh
            mv "$LAFAN_TEMP_DIR/lafan1/lafan"/* "$LAFAN_TEMP_DIR/" 2>/dev/null || true
            rm -rf "$LAFAN_TEMP_DIR/lafan1" 2>/dev/null || true
        elif [ -d "$LAFAN_TEMP_DIR/lafan1" ]; then
            # Structure: lafan1/*.bvh
            mv "$LAFAN_TEMP_DIR/lafan1"/* "$LAFAN_TEMP_DIR/" 2>/dev/null || true
            rmdir "$LAFAN_TEMP_DIR/lafan1" 2>/dev/null || true
        fi
    else
        echo "LAFAN BVH files already extracted. Skipping extraction."
    fi

    # Ensure lafan1 processing code is available in data_utils.
    # Use GIT_LFS_SKIP_SMUDGE to avoid downloading large LFS objects that are not needed.
    LAFAN_CODE_DIR="$DATA_UTILS_DIR/lafan1"
    UBISOFT_REPO_DIR="$DATA_UTILS_DIR/ubisoft-laforge-animation-dataset"
    if [ ! -d "$LAFAN_CODE_DIR" ]; then
        echo "Preparing lafan1 processing code..."
        pushd "$DATA_UTILS_DIR" > /dev/null
        if [ ! -d "$UBISOFT_REPO_DIR/lafan1" ]; then
            if [ ! -d "$UBISOFT_REPO_DIR" ]; then
                GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 https://github.com/ubisoft/ubisoft-laforge-animation-dataset.git
            else
                GIT_LFS_SKIP_SMUDGE=1 git -C "$UBISOFT_REPO_DIR" checkout -q HEAD -- lafan1 || true
            fi
        fi
        if [ -d "$UBISOFT_REPO_DIR/lafan1" ] && [ ! -d "$LAFAN_CODE_DIR" ]; then
            cp -r "$UBISOFT_REPO_DIR/lafan1" "$LAFAN_CODE_DIR"
        fi
        popd > /dev/null
        if [ ! -d "$LAFAN_CODE_DIR" ]; then
            echo "Error: failed to prepare lafan1 processing code at $LAFAN_CODE_DIR"
            exit 1
        fi
    else
        echo "lafan1 processing code already available."
    fi

    # Convert BVH files to .npy format
    echo "Converting BVH files to .npy format..."
    pushd "$DATA_UTILS_DIR" > /dev/null
    python extract_global_positions.py --input_dir "$LAFAN_TEMP_DIR" --output_dir "$LAFAN_DATA_DIR"
    popd > /dev/null

    echo "LAFAN data processing complete!"
fi

# Step 1: Run retargeting
RETARGETED_FILE="$RETARGETING_DIR/demo_results/g1/robot_only/lafan/dance2_subject1.npz"
if [ -f "$RETARGETED_FILE" ]; then
    echo "Retargeted file already exists at $RETARGETED_FILE. Skipping retargeting."
else
    echo "Running retargeting..."
    python examples/robot_retarget.py --data_path "$LAFAN_DATA_DIR" --task-type robot_only --task-name dance2_subject1 --data_format lafan --task-config.ground-range -10 10 --save_dir "$RETARGETING_DIR/demo_results/g1/robot_only/lafan" --retargeter.foot-sticking-tolerance 0.02
fi

# Step 2: Run data conversion
echo "Running data conversion..."
CONVERT_HEADLESS_ARGS=()
if [ -z "${DISPLAY:-}" ]; then
    echo "DISPLAY is not set. Running data conversion in headless mode."
    CONVERT_HEADLESS_ARGS+=(--headless)
    CONVERT_HEADLESS_ARGS+=(--live-viser)
fi
python data_conversion/convert_data_format_mj.py --input_file "$RETARGETED_FILE" --output_fps 50 --output_name "$RETARGETING_DIR/converted_res/robot_only/dance2_subject1_mj_fps50.npz" --data_format lafan --object_name "ground" --once "${CONVERT_HEADLESS_ARGS[@]}"

# Step 3: Source IsaacSim setup script (for whole-body tracking training)
echo "Sourcing IsaacSim setup..."
cd "$PROJECT_ROOT"
ISAACSIM_CONDA_ENV_NAME="${ISAACSIM_CONDA_ENV_NAME:-hssim}" \
    source "$PROJECT_ROOT/scripts/source_isaacsim_setup.sh"

# Step 4: Run whole-body tracking training
echo "Running whole-body tracking training..."
CONVERTED_FILE="$RETARGETING_DIR/converted_res/robot_only/dance2_subject1_mj_fps50.npz"
DISPLAY= python src/holosoma/holosoma/train_agent.py \
    exp:g1-29dof-wbt \
    logger:wandb \
    --command.setup_terms.motion_command.params.motion_config.motion_file="$CONVERTED_FILE"

echo "Done!"
