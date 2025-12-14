#!/bin/bash
# Script to explore dataset structure and find video files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
OUTPUT_DIR="${SCRIPT_DIR}/../output"

echo "=== Dataset Exploration Script ==="
echo "Data directory: ${DATA_DIR}"
echo ""

# Check if data directory exists
if [ ! -d "${DATA_DIR}" ]; then
    echo "ERROR: Data directory not found: ${DATA_DIR}"
    exit 1
fi

# Function to find and count video files
find_videos() {
    local dataset_path=$1
    local dataset_name=$2
    
    echo "=== ${dataset_name} ==="
    if [ ! -d "${dataset_path}" ]; then
        echo "  Directory not found: ${dataset_path}"
        return
    fi
    
    echo "  Searching for video files..."
    local video_count=$(find "${dataset_path}" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.wmv" \) 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "${video_count}" -eq 0 ]; then
        echo "  No video files found"
        echo "  Checking for other file types..."
        local audio_count=$(find "${dataset_path}" -type f -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
        echo "  Audio files (.wav): ${audio_count}"
        
        # Show directory structure
        echo "  Directory structure (top level):"
        ls -la "${dataset_path}" | head -10 | sed 's/^/    /'
    else
        echo "  Found ${video_count} video files"
        echo "  Sample video files:"
        find "${dataset_path}" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.wmv" \) 2>/dev/null | head -5 | sed 's/^/    /'
    fi
    echo ""
}

# Check CMU-MOSEI dataset
find_videos "${DATA_DIR}/CMU-MOSEI" "CMU-MOSEI Dataset"

# Check RAVDESS dataset
find_videos "${DATA_DIR}/RAVDESS" "RAVDESS Dataset"

# Check for sample videos in OpenFace samples directory
echo "=== OpenFace Sample Videos ==="
SAMPLES_DIR="${SCRIPT_DIR}/../samples"
if [ -d "${SAMPLES_DIR}" ]; then
    sample_count=$(find "${SAMPLES_DIR}" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.wmv" \) 2>/dev/null | wc -l | tr -d ' ')
    echo "Found ${sample_count} sample video files"
    find "${SAMPLES_DIR}" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.wmv" \) 2>/dev/null | sed 's/^/  /'
else
    echo "Samples directory not found"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "To process videos with OpenFace, you need video files (.mp4, .avi, .mov, .mkv, .wmv)"
echo "If datasets only contain audio files, you may need to:"
echo "  1. Download video versions of the datasets"
echo "  2. Extract frames from video sources"
echo "  3. Use sample videos for testing"
echo ""
