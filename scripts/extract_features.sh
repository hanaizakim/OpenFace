#!/bin/bash
# Script to extract facial features from video files using OpenFace FeatureExtraction
# This script processes videos from CMU-MOSEI and RAVDESS datasets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
OUTPUT_DIR="${SCRIPT_DIR}/../output"
LOG_DIR="${OUTPUT_DIR}/logs"

# Default DATA_MOUNT if not set
DATA_MOUNT="${DATA_MOUNT:-/tmp/openface}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in Docker or need to use docker/podman
check_docker() {
    if [ -f /.dockerenv ]; then
        print_info "Running inside Docker container"
        return 0
    else
        print_info "Running on host, will use docker/podman"
        # Check for docker or podman
        if command -v podman &> /dev/null; then
            DOCKER_CMD="podman"
            print_info "Using podman"
        elif command -v docker &> /dev/null; then
            DOCKER_CMD="docker"
            print_info "Using docker"
        else
            print_error "Neither docker nor podman found. Please install one or run inside container."
            exit 1
        fi
        return 1
    fi
}

# Create output directories
setup_directories() {
    print_info "Setting up output directories..."
    mkdir -p "${OUTPUT_DIR}/CMU-MOSEI"
    mkdir -p "${OUTPUT_DIR}/RAVDESS"
    mkdir -p "${LOG_DIR}"
    print_info "Output directory: ${OUTPUT_DIR}"
}

# Find all video files in a directory
find_videos() {
    local search_dir=$1
    find "${search_dir}" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.wmv" \) 2>/dev/null
}

# Process a single video file
process_video() {
    local video_path=$1
    local output_base_dir=$2
    local dataset_name=$3
    local is_docker=$4
    
    # Get video filename without extension
    local video_name=$(basename "${video_path}")
    local video_basename="${video_name%.*}"
    
    # Create dataset-specific output directory
    local output_dir="${output_base_dir}/${dataset_name}"
    mkdir -p "${output_dir}"
    
    # Log file for this video
    local log_file="${LOG_DIR}/${dataset_name}_${video_basename}.log"
    
    print_info "Processing: ${video_name}"
    print_info "  Input: ${video_path}"
    print_info "  Output: ${output_dir}"
    
    # FeatureExtraction command (no visualization flags to avoid GUI issues)
    # Add -tracked flag if OUTPUT_TRACKED_VIDEO is set
    local cmd="FeatureExtraction -f \"${video_path}\" -out_dir \"${output_dir}\" -2Dfp -3Dfp -pdmparams -pose -aus -gaze"
    if [ "${OUTPUT_TRACKED_VIDEO:-0}" = "1" ]; then
        cmd="${cmd} -tracked"
    fi
    
    if [ "${is_docker}" -eq 0 ]; then
        # Running inside container
        eval "${cmd}" > "${log_file}" 2>&1
        local exit_code=$?
    else
        # Running on host, use docker/podman exec
        local container_name="openface"
        
        # Copy video to container if path is outside container
        local video_in_container="${video_path}"
        if [[ "${video_path}" != /*tmp/* ]] && [[ "${video_path}" != /root/* ]]; then
            # Video is on host, need to copy to container
            local temp_video="/tmp/$(basename ${video_path})"
            print_info "  Copying video to container..."
            ${DOCKER_CMD} cp "${video_path}" "${container_name}:${temp_video}" > /dev/null 2>&1
            video_in_container="${temp_video}"
        fi
        
        # Adjust output path for container
        local output_in_container="${output_dir}"
        if [[ "${output_dir}" != /*tmp/* ]] && [[ "${output_dir}" != /root/* ]]; then
            # Output is on host, use /tmp in container and copy back later
            output_in_container="/tmp/output_$(basename ${video_basename})"
            ${DOCKER_CMD} exec ${container_name} mkdir -p "${output_in_container}" > /dev/null 2>&1
        fi
        
        # Build command with container paths (no verbose to reduce output, no GUI)
        # Add -tracked flag if OUTPUT_TRACKED_VIDEO is set
        local cmd_container="FeatureExtraction -f \"${video_in_container}\" -out_dir \"${output_in_container}\" -2Dfp -3Dfp -pdmparams -pose -aus -gaze"
        if [ "${OUTPUT_TRACKED_VIDEO:-0}" = "1" ]; then
            cmd_container="${cmd_container} -tracked"
        fi
        
        # Execute in container (disable DISPLAY to prevent GUI issues)
        eval "${DOCKER_CMD} exec -e DISPLAY= ${container_name} ${cmd_container}" > "${log_file}" 2>&1
        local exit_code=$?
        
        # Copy output back if needed
        if [[ "${output_dir}" != /*tmp/* ]] && [[ "${output_dir}" != /root/* ]]; then
            ${DOCKER_CMD} cp "${container_name}:${output_in_container}/." "${output_dir}/" > /dev/null 2>&1
            # Clean up temp files in container
            ${DOCKER_CMD} exec ${container_name} rm -rf "${video_in_container}" "${output_in_container}" > /dev/null 2>&1
        fi
    fi
    
    if [ ${exit_code} -eq 0 ]; then
        # Check if CSV file was created
        local csv_file="${output_dir}/${video_basename}.csv"
        local success_msg="  ✓ Success! Output: ${csv_file}"
        
        if [ -f "${csv_file}" ]; then
            local csv_size=$(du -h "${csv_file}" | cut -f1)
            success_msg="${success_msg} (${csv_size})"
        else
            print_warn "  ⚠ Command succeeded but CSV file not found: ${csv_file}"
            return 1
        fi
        
        # Check if tracked video was created
        if [ "${OUTPUT_TRACKED_VIDEO:-0}" = "1" ]; then
            local tracked_video="${output_dir}/${video_basename}.avi"
            if [ -f "${tracked_video}" ]; then
                local video_size=$(du -h "${tracked_video}" | cut -f1)
                success_msg="${success_msg}, Tracked video: ${tracked_video} (${video_size})"
            fi
        fi
        
        print_info "${success_msg}"
        return 0
    else
        print_error "  ✗ Failed with exit code ${exit_code}"
        print_error "  Check log: ${log_file}"
        return 1
    fi
}

# Process all videos in a dataset
process_dataset() {
    local dataset_path=$1
    local dataset_name=$2
    local output_base_dir=$3
    local is_docker=$4
    
    print_info "=== Processing ${dataset_name} ==="
    
    # Find all video files
    local video_files=($(find_videos "${dataset_path}"))
    local total_videos=${#video_files[@]}
    
    if [ ${total_videos} -eq 0 ]; then
        print_warn "No video files found in ${dataset_path}"
        print_warn "Skipping ${dataset_name} (only audio or other file types found)"
        return 1
    fi
    
    print_info "Found ${total_videos} video files"
    
    # Counters
    local success_count=0
    local fail_count=0
    
    # Process each video
    for video_path in "${video_files[@]}"; do
        if process_video "${video_path}" "${output_base_dir}" "${dataset_name}" "${is_docker}"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done
    
    # Summary
    print_info "=== ${dataset_name} Summary ==="
    print_info "Total videos: ${total_videos}"
    print_info "Successful: ${success_count}"
    print_info "Failed: ${fail_count}"
    echo ""
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [DATASET_PATH...]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -s, --samples       Process sample videos from OpenFace samples directory"
    echo "  -d, --dir DIR       Process videos from a specific directory"
    echo "  -t, --tracked       Generate tracked videos with gaze/landmark overlays"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Process all datasets (CMU-MOSEI, RAVDESS)"
    echo "  $0 --samples                          # Process sample videos"
    echo "  $0 --samples --tracked                # Process samples with tracked video output"
    echo "  $0 --dir /path/to/videos              # Process videos from specific directory"
    echo "  $0 data/CMU-MOSEI data/RAVDESS        # Process specific datasets"
    echo ""
    echo "Tracked Videos:"
    echo "  Use -t/--tracked to generate .avi files with overlays showing:"
    echo "    - Facial landmarks (2D points)"
    echo "    - Gaze direction (lines from eyes)"
    echo "    - Head pose (coordinate axes)"
    echo "    - Action Unit information"
    echo ""
}

# Main function
main() {
    local process_samples=0
    local custom_dirs=()
    local output_tracked=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--samples)
                process_samples=1
                shift
                ;;
            -d|--dir)
                if [ -z "$2" ]; then
                    print_error "Directory path required after -d/--dir"
                    exit 1
                fi
                custom_dirs+=("$2")
                shift 2
                ;;
            -t|--tracked)
                output_tracked=1
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                custom_dirs+=("$1")
                shift
                ;;
        esac
    done
    
    # Export flag for use in process_video function
    export OUTPUT_TRACKED_VIDEO=${output_tracked}
    
    print_info "=== OpenFace Feature Extraction Script ==="
    echo ""
    
    # Check if running in Docker
    local is_docker=0
    if ! check_docker; then
        is_docker=1
        # Check if container is running
        if [ "${DOCKER_CMD}" = "podman" ]; then
            if ! ${DOCKER_CMD} ps --format "{{.Names}}" | grep -q "^openface$"; then
                print_error "Container 'openface' is not running"
                print_info "Start it with: podman-compose up -d"
                exit 1
            fi
        else
            if ! ${DOCKER_CMD} ps --format "{{.Names}}" | grep -q "^openface$"; then
                print_error "Container 'openface' is not running"
                print_info "Start it with: docker-compose up -d"
                exit 1
            fi
        fi
    fi
    
    # Setup directories
    setup_directories
    
    # Determine data path based on context
    if [ ${is_docker} -eq 0 ]; then
        # Inside container, use DATA_MOUNT
        local data_path="${DATA_MOUNT}/data"
        local output_path="${DATA_MOUNT}/output"
        local samples_path="${DATA_MOUNT}/samples"
    else
        # On host, use relative paths
        local data_path="${DATA_DIR}"
        local output_path="${OUTPUT_DIR}"
        local samples_path="${SCRIPT_DIR}/../samples"
    fi
    
    print_info "Data path: ${data_path}"
    print_info "Output path: ${output_path}"
    echo ""
    
    # Process custom directories if specified
    if [ ${#custom_dirs[@]} -gt 0 ]; then
        for dir in "${custom_dirs[@]}"; do
            local dir_name=$(basename "${dir}")
            if [ -d "${dir}" ]; then
                process_dataset "${dir}" "${dir_name}" "${output_path}" ${is_docker}
            else
                print_warn "Directory not found: ${dir}"
            fi
        done
    fi
    
    # Process samples if requested
    if [ ${process_samples} -eq 1 ]; then
        if [ -d "${samples_path}" ]; then
            process_dataset "${samples_path}" "samples" "${output_path}" ${is_docker}
        else
            print_warn "Samples directory not found: ${samples_path}"
        fi
    fi
    
    # Process default datasets if no custom directories or samples specified
    if [ ${#custom_dirs[@]} -eq 0 ] && [ ${process_samples} -eq 0 ]; then
        # Process CMU-MOSEI dataset
        if [ -d "${data_path}/CMU-MOSEI" ]; then
            process_dataset "${data_path}/CMU-MOSEI" "CMU-MOSEI" "${output_path}" ${is_docker}
        else
            print_warn "CMU-MOSEI directory not found: ${data_path}/CMU-MOSEI"
        fi
        
        # Process RAVDESS dataset
        if [ -d "${data_path}/RAVDESS" ]; then
            process_dataset "${data_path}/RAVDESS" "RAVDESS" "${output_path}" ${is_docker}
        else
            print_warn "RAVDESS directory not found: ${data_path}/RAVDESS"
        fi
    fi
    
    # Final summary
    print_info "=== Processing Complete ==="
    print_info "Output directory: ${output_path}"
    print_info "Logs directory: ${LOG_DIR}"
    echo ""
}

# Run main function
main "$@"
