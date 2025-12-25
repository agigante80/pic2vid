#!/bin/bash

# img2video.sh - Create WhatsApp-compatible video from images
# Usage: ./img2video.sh [-d duration] [-o output] image1 image2 image3 ...

set -e

# Default values
DURATION=3
DURATIONS=()
OUTPUT="output.mp4"
SORT_BY="none"
FORMAT="mp4"
METADATA=()
IMAGES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            shift
            # Collect all numeric arguments as durations
            while [[ $# -gt 0 && "$1" =~ ^[0-9]+\.?[0-9]*$ ]]; do
                DURATIONS+=("$1")
                shift
            done
            # If no durations collected, error
            if [ ${#DURATIONS[@]} -eq 0 ]; then
                echo "Error: -d/--duration requires at least one numeric value"
                exit 1
            fi
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -s|--sort)
            SORT_BY="$2"
            if [[ ! "$SORT_BY" =~ ^(ctime|mtime|name|none)$ ]]; then
                echo "Error: Invalid sort option '$SORT_BY'. Valid options: ctime, mtime, name, none"
                exit 1
            fi
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            if [[ ! "$FORMAT" =~ ^(mp4|gif)$ ]]; then
                echo "Error: Invalid format option '$FORMAT'. Valid options: mp4, gif"
                exit 1
            fi
            # Update output extension if using default filename
            if [ "$OUTPUT" = "output.mp4" ]; then
                OUTPUT="output.$FORMAT"
            fi
            shift 2
            ;;
        -m|--metadata)
            # Validate key=value format
            if [[ ! "$2" =~ ^[^=]+=.+$ ]]; then
                echo "Error: Metadata must be in key=value format"
                exit 1
            fi
            METADATA+=("$2")
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-d duration(s)] [-o output] [-s sort] [-f format] [-m metadata] image1 image2 image3 ..."
            echo ""
            echo "Options:"
            echo "  -d, --duration  Duration in seconds for each image"
            echo "                  Single value: applies to all images (default: 3)"
            echo "                  Multiple values: per-image durations"
            echo "                  Example: -d 2 (all images 2s)"
            echo "                  Example: -d 1 1 1 4 (first 3 images 1s, last 4s)"
            echo "  -o, --output    Output filename (default: output.mp4 or output.gif)"
            echo "  -s, --sort      Sort images by:"
            echo "                  ctime  - creation time (oldest first)"
            echo "                  mtime  - modification time (oldest first)"
            echo "                  name   - alphabetical order"
            echo "                  none   - no sorting, use order provided (default)"
            echo "  -f, --format    Output format: mp4 or gif (default: mp4)"
            echo "  -m, --metadata  Add metadata to output (can be used multiple times)"
            echo "                  Format: key=value"
            echo "                  Example: -m title=\"My Video\" -m author=\"John Doe\""
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 img1.jpg img2.jpg img3.jpg"
            echo "  $0 -d 5 -o myvideo.mp4 img1.jpg img2.jpg img3.jpg"
            echo "  $0 -d 1 2 3 img1.jpg img2.jpg img3.jpg"
            echo "  $0 -s mtime -d 2 *.jpg"
            echo "  $0 -f gif -d 2 -o animation.gif *.jpg"
            echo "  $0 -m title=\"Vacation 2025\" -m artist=\"John\" -d 3 *.jpg"
            echo ""
            echo "For more information and examples, visit: https://github.com/agigante80/pic2vid"
            exit 0
            ;;
        *)
            IMAGES+=("$1")
            shift
            ;;
    esac
done

# Check if required dependencies are installed
MISSING_DEPS=()

if ! command -v ffmpeg &> /dev/null; then
    MISSING_DEPS+=("ffmpeg")
fi

if ! command -v ffprobe &> /dev/null; then
    MISSING_DEPS+=("ffprobe")
fi

if ! command -v bc &> /dev/null; then
    MISSING_DEPS+=("bc")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Installation instructions:"
    echo ""
    echo "Ubuntu/Debian:"
    if [[ " ${MISSING_DEPS[@]} " =~ " ffmpeg " ]] || [[ " ${MISSING_DEPS[@]} " =~ " ffprobe " ]]; then
        echo "  sudo apt update && sudo apt install ffmpeg"
    fi
    if [[ " ${MISSING_DEPS[@]} " =~ " bc " ]]; then
        echo "  sudo apt install bc"
    fi
    echo ""
    echo "Fedora/RHEL:"
    if [[ " ${MISSING_DEPS[@]} " =~ " ffmpeg " ]] || [[ " ${MISSING_DEPS[@]} " =~ " ffprobe " ]]; then
        echo "  sudo dnf install ffmpeg"
    fi
    if [[ " ${MISSING_DEPS[@]} " =~ " bc " ]]; then
        echo "  sudo dnf install bc"
    fi
    echo ""
    echo "Arch Linux:"
    if [[ " ${MISSING_DEPS[@]} " =~ " ffmpeg " ]] || [[ " ${MISSING_DEPS[@]} " =~ " ffprobe " ]]; then
        echo "  sudo pacman -S ffmpeg"
    fi
    if [[ " ${MISSING_DEPS[@]} " =~ " bc " ]]; then
        echo "  sudo pacman -S bc"
    fi
    echo ""
    echo "macOS (via Homebrew):"
    if [[ " ${MISSING_DEPS[@]} " =~ " ffmpeg " ]] || [[ " ${MISSING_DEPS[@]} " =~ " ffprobe " ]]; then
        echo "  brew install ffmpeg"
    fi
    if [[ " ${MISSING_DEPS[@]} " =~ " bc " ]]; then
        echo "  brew install bc"
    fi
    exit 1
fi

# Validate inputs
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Error: No images provided."
    echo "Usage: $0 [-d duration] [-o output] image1 image2 image3 ..."
    exit 1
fi

# Check if all image files exist
for img in "${IMAGES[@]}"; do
    if [ ! -f "$img" ]; then
        echo "Error: Image file not found: $img"
        exit 1
    fi
done

# Sort images if requested
if [ "$SORT_BY" != "none" ]; then
    echo "Sorting images by $SORT_BY..."
    SORTED_IMAGES=()
    
    case "$SORT_BY" in
        ctime)
            # Sort by creation/change time
            while IFS= read -r -d '' file; do
                SORTED_IMAGES+=("$file")
            done < <(stat -c '%W %n' "${IMAGES[@]}" 2>/dev/null | sort -n | cut -d' ' -f2- | tr '\n' '\0' || \
                     stat -f '%B %N' "${IMAGES[@]}" 2>/dev/null | sort -n | cut -d' ' -f2- | tr '\n' '\0')
            ;;
        mtime)
            # Sort by modification time
            while IFS= read -r -d '' file; do
                SORTED_IMAGES+=("$file")
            done < <(stat -c '%Y %n' "${IMAGES[@]}" 2>/dev/null | sort -n | cut -d' ' -f2- | tr '\n' '\0' || \
                     stat -f '%m %N' "${IMAGES[@]}" 2>/dev/null | sort -n | cut -d' ' -f2- | tr '\n' '\0')
            ;;
        name)
            # Sort alphabetically
            IFS=$'\n' SORTED_IMAGES=($(sort <<<"${IMAGES[*]}"))
            unset IFS
            ;;
    esac
    
    IMAGES=("${SORTED_IMAGES[@]}")
fi

# Handle duration logic
if [ ${#DURATIONS[@]} -eq 0 ]; then
    # No -d flag provided, use default for all images
    DURATION=3
    for ((i=0; i<${#IMAGES[@]}; i++)); do
        DURATIONS+=("$DURATION")
    done
elif [ ${#DURATIONS[@]} -eq 1 ]; then
    # Single duration provided, apply to all images
    DURATION="${DURATIONS[0]}"
    DURATIONS=()
    for ((i=0; i<${#IMAGES[@]}; i++)); do
        DURATIONS+=("$DURATION")
    done
elif [ ${#DURATIONS[@]} -ne ${#IMAGES[@]} ]; then
    # Multiple durations but count doesn't match images
    echo "Error: Number of durations (${#DURATIONS[@]}) must match number of images (${#IMAGES[@]})"
    echo "Provided: ${DURATIONS[*]}"
    echo "Images: ${#IMAGES[@]}"
    exit 1
fi

echo "Creating video from ${#IMAGES[@]} images..."
if [ ${#DURATIONS[@]} -eq ${#IMAGES[@]} ]; then
    echo "Durations: ${DURATIONS[*]}s"
else
    echo "Duration per image: ${DURATION}s"
fi
echo "Output file: $OUTPUT"

# Determine maximum dimensions from all images
echo "Analyzing image dimensions..."
MAX_WIDTH=0
MAX_HEIGHT=0

for img in "${IMAGES[@]}"; do
    # Get image dimensions using ffprobe
    DIMS=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$img" 2>/dev/null)
    WIDTH=$(echo "$DIMS" | cut -d'x' -f1)
    HEIGHT=$(echo "$DIMS" | cut -d'x' -f2)
    
    if [ "$WIDTH" -gt "$MAX_WIDTH" ]; then
        MAX_WIDTH=$WIDTH
    fi
    if [ "$HEIGHT" -gt "$MAX_HEIGHT" ]; then
        MAX_HEIGHT=$HEIGHT
    fi
done

# Cap at 720px for WhatsApp compatibility
if [ "$MAX_WIDTH" -gt 720 ]; then
    SCALE_FACTOR=$(echo "scale=4; 720 / $MAX_WIDTH" | bc)
    MAX_WIDTH=720
    MAX_HEIGHT=$(echo "scale=0; $MAX_HEIGHT * $SCALE_FACTOR / 1" | bc)
fi
if [ "$MAX_HEIGHT" -gt 720 ]; then
    SCALE_FACTOR=$(echo "scale=4; 720 / $MAX_HEIGHT" | bc)
    MAX_HEIGHT=720
    MAX_WIDTH=$(echo "scale=0; $MAX_WIDTH * $SCALE_FACTOR / 1" | bc)
fi

# Ensure even dimensions (required for H.264)
MAX_WIDTH=$((MAX_WIDTH + MAX_WIDTH % 2))
MAX_HEIGHT=$((MAX_HEIGHT + MAX_HEIGHT % 2))

echo "Video dimensions: ${MAX_WIDTH}x${MAX_HEIGHT}"

# Create temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create a temporary file list for ffmpeg concat
FILELIST="$TEMP_DIR/filelist.txt"

# Process each image: resize to reasonable dimensions and create individual video segments
for i in "${!IMAGES[@]}"; do
    img="${IMAGES[$i]}"
    img_duration="${DURATIONS[$i]}"
    echo "Processing image $((i+1))/${#IMAGES[@]}: $img (${img_duration}s)"
    
    # Create a short video from each image with proper scaling
    # Scale to fit within max dimensions while maintaining aspect ratio
    # Use format suitable for WhatsApp: H.264 video codec, yuv420p pixel format
    ffmpeg -loop 1 -i "$img" -vf "scale='min($MAX_WIDTH,iw)':'min($MAX_HEIGHT,ih)':force_original_aspect_ratio=decrease,pad=$MAX_WIDTH:$MAX_HEIGHT:(ow-iw)/2:(oh-ih)/2:black" \
        -c:v libx264 -t "$img_duration" -pix_fmt yuv420p -r 25 \
        "$TEMP_DIR/segment_$(printf "%03d" $i).mp4" -y -loglevel error
    
    # Add to concat list
    echo "file 'segment_$(printf "%03d" $i).mp4'" >> "$FILELIST"
done

echo "Concatenating segments..."

# Build metadata arguments
METADATA_ARGS=()
for meta in "${METADATA[@]}"; do
    METADATA_ARGS+=("-metadata" "$meta")
done

if [ "$FORMAT" = "gif" ]; then
    # Create GIF from segments
    # Use palette for better quality GIF
    ffmpeg -f concat -safe 0 -i "$FILELIST" \
        "${METADATA_ARGS[@]}" \
        -vf "split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
        "$OUTPUT" -y -loglevel error
else
    # Concatenate all segments into final video
    # Add silent audio track (WhatsApp prefers videos with audio)
    # Use high compression to keep file size under 16MB
    ffmpeg -f concat -safe 0 -i "$FILELIST" \
        -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
        "${METADATA_ARGS[@]}" \
        -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k -shortest \
        -movflags +faststart -pix_fmt yuv420p \
        "$OUTPUT" -y -loglevel error
fi

# Check output file size
FILESIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
FILESIZE_MB=$((FILESIZE / 1024 / 1024))
FILESIZE_KB=$((FILESIZE / 1024))

# Calculate expected total duration
EXPECTED_DURATION=0
for d in "${DURATIONS[@]}"; do
    EXPECTED_DURATION=$(echo "$EXPECTED_DURATION + $d" | bc)
done

# Get actual video duration using ffprobe
ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT" 2>/dev/null | cut -d'.' -f1)

echo "✓ Video created successfully: $OUTPUT"
if [ $FILESIZE_MB -gt 0 ]; then
    echo "  File size: ${FILESIZE_MB}MB"
else
    echo "  File size: ${FILESIZE_KB}KB"
fi
echo "  Total duration: ${ACTUAL_DURATION}s"

# Compare expected vs actual duration
if [ "$ACTUAL_DURATION" != "$EXPECTED_DURATION" ]; then
    echo "  ⚠ Warning: Duration mismatch! Expected ${EXPECTED_DURATION}s, got ${ACTUAL_DURATION}s"
fi

# Display metadata if any was added
if [ ${#METADATA[@]} -gt 0 ]; then
    echo ""
    if [ "$FORMAT" = "gif" ]; then
        echo "Metadata information:"
        echo "  ℹ GIF format does not support embedded metadata"
    else
        echo "Metadata verification:"
        # Use ffprobe to read back metadata from the file
        EMBEDDED_METADATA=$(ffprobe -v quiet -show_entries format_tags -of default=noprint_wrappers=1 "$OUTPUT" 2>/dev/null | grep "TAG:" | sed 's/TAG://')
        
        if [ -n "$EMBEDDED_METADATA" ]; then
            echo "$EMBEDDED_METADATA" | while IFS= read -r line; do
                echo "  ✓ $line"
            done
            
            # Compare requested vs embedded
            for requested in "${METADATA[@]}"; do
                key="${requested%%=*}"
                value="${requested#*=}"
                # Remove quotes if present
                value="${value#\"}"
                value="${value%\"}"
                
                if echo "$EMBEDDED_METADATA" | grep -q "^${key}="; then
                    embedded_value=$(echo "$EMBEDDED_METADATA" | grep "^${key}=" | cut -d'=' -f2-)
                    if [ "$embedded_value" != "$value" ]; then
                        echo "  ⚠ Warning: Metadata mismatch for '$key'"
                        echo "    Requested: $value"
                        echo "    Embedded: $embedded_value"
                    fi
                else
                    echo "  ⚠ Warning: Metadata key '$key' not found in output file"
                fi
            done
        else
            echo "  ⚠ Warning: No metadata found in output file"
        fi
    fi
fi

# Warn if file is too large for WhatsApp
if [ $FILESIZE_MB -gt 16 ]; then
    echo ""
    echo "⚠ WARNING: File size exceeds WhatsApp's 16MB limit!"
    echo "  Consider reducing image quality or using fewer images."
    echo "  You can re-run with higher compression using:"
    echo "  ffmpeg -i $OUTPUT -c:v libx264 -crf 28 -c:a aac -b:a 96k ${OUTPUT%.mp4}_compressed.mp4"
fi

echo ""
echo "Done! Your WhatsApp-compatible video is ready."
