# OpenFace Feature Extraction Scripts

This directory contains scripts for extracting facial features from video files using OpenFace's FeatureExtraction tool.

## Scripts

### `check_datasets.sh`
Explores the dataset structure and identifies video files available for processing.

**Usage:**
```bash
bash scripts/check_datasets.sh
```

This script will:
- Search for video files in CMU-MOSEI and RAVDESS datasets
- Report the number of video files found
- Show sample video files
- Display directory structure

### `extract_features.sh`
Main script for processing video files with OpenFace FeatureExtraction.

**Usage:**
```bash
# Process all default datasets (CMU-MOSEI, RAVDESS)
bash scripts/extract_features.sh

# Process sample videos only
bash scripts/extract_features.sh --samples

# Process videos from a specific directory
bash scripts/extract_features.sh --dir /path/to/videos

# Process specific dataset directories
bash scripts/extract_features.sh data/CMU-MOSEI data/RAVDESS

# Show help
bash scripts/extract_features.sh --help
```

**Options:**
- `-h, --help` - Show usage information
- `-s, --samples` - Process sample videos from OpenFace samples directory
- `-d, --dir DIR` - Process videos from a specific directory
- `-t, --tracked` - Generate tracked videos with gaze/landmark overlays (creates .avi files)

This script will:
- Automatically detect if running in Docker/Podman or on host
- Find all video files in the specified directories
- Skip directories with no video files (shows warning)
- Process each video with FeatureExtraction
- Generate CSV files with facial features
- Create logs for each processed video

**Features extracted:**
- 2D and 3D facial landmarks
- Head pose (pitch, yaw, roll)
- Action Units (facial expressions)
- Gaze direction and angles
- Shape parameters

## Current Dataset Status

**Note:** As of the initial setup, the extracted datasets (CMU-MOSEI and RAVDESS) contain only audio files (.wav), not video files. 

- **CMU-MOSEI**: Contains 8,636 audio files
- **RAVDESS**: Contains 2,880 audio files

To process videos with OpenFace, you will need:
1. Video versions of these datasets (typically .mp4, .avi, .mov, .mkv, or .wmv files)
2. Or use the sample videos in `/samples/` directory for testing

## Output Structure

Processed videos will generate CSV files (and optionally tracked videos) in:
```
output/
├── CMU-MOSEI/
│   ├── video1.csv
│   ├── video1.avi          # Tracked video (if --tracked used)
│   ├── video2.csv
│   └── ...
├── RAVDESS/
│   ├── video1.csv
│   ├── video1.avi          # Tracked video (if --tracked used)
│   └── ...
└── logs/
    ├── CMU-MOSEI_video1.log
    └── ...
```

## CSV File Contents

Each CSV file contains:
- **Frame information**: frame number, timestamp, confidence, success flag
- **Gaze data**: gaze direction vectors and angles
- **Facial landmarks**: 2D and 3D coordinates for 68 facial points
- **Head pose**: position (x, y, z) and orientation (pitch, yaw, roll)
- **Action Units**: intensity values for AU01-AU28
- **Shape parameters**: PDM (Point Distribution Model) parameters

## Tracked Video Files

When using the `--tracked` flag, each processed video also generates a `.avi` file with visual overlays:
- **Format**: AVI (DivX 4 codec)
- **Resolution**: Matches input video (typically 640x480)
- **Frame rate**: Matches input video (~15-30 fps)
- **Overlays include**:
  - 68 facial landmark points (green dots)
  - Gaze direction vectors (lines from eyes)
  - Head pose coordinate axes
  - Action Unit labels and intensities
  - Confidence indicators

These videos can be played in any standard video player to visualize the tracking results.

## Requirements

- Docker or Podman container with OpenFace installed
- Container named "openface" must be running
- Video files in supported formats (.mp4, .avi, .mov, .mkv, .wmv)

## Quick Start - Process Sample Videos

To process the sample videos included with OpenFace:

```bash
# Extract features only (CSV files)
bash scripts/extract_features.sh --samples

# Extract features AND generate tracked videos with overlays
bash scripts/extract_features.sh --samples --tracked
```

This will process all videos in the `samples/` directory and create:
- CSV files in `output/samples/` (always generated)
- AVI video files with overlays in `output/samples/` (when using `--tracked` flag)

## Testing

A test was successfully performed with a sample video:
- Input: `samples/default.wmv`
- Output: CSV file with 1.2MB of feature data
- Status: ✓ Working correctly

## Troubleshooting

If videos are not found:
1. Check that video files exist in the dataset directories
2. Verify file formats are supported
3. Use `check_datasets.sh` to explore the dataset structure

If processing fails:
1. Check log files in `output/logs/`
2. Verify the container is running: `podman ps` or `docker ps`
3. Ensure FeatureExtraction is available in the container
