# pic2vid - Image Sequence to Video/GIF Converter

A powerful bash script that converts image sequences into WhatsApp-compatible MP4 videos or animated GIFs with extensive customization options.

## Features

- ✅ **Multiple Output Formats**: MP4 video or animated GIF
- ✅ **Flexible Duration Control**: Set global duration or individual per-image timings
- ✅ **Smart Image Sorting**: Sort by creation time, modification time, or alphabetically
- ✅ **Adaptive Dimensions**: Automatically uses largest image dimensions (respects aspect ratios)
- ✅ **Metadata Support**: Add custom metadata/EXIF tags to output files
- ✅ **WhatsApp Optimized**: H.264 codec, AAC audio, under 16MB target
- ✅ **Duration Verification**: Validates actual output duration matches expectations
- ✅ **Dependency Detection**: Automatic check with installation guidance for missing tools

## Requirements

The script automatically checks for required dependencies and provides installation instructions if anything is missing:

- **ffmpeg** - Video/image processing
- **ffprobe** - Media file analysis
- **bc** - Floating-point calculations

### Installing Dependencies

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg bc

# Fedora/RHEL
sudo dnf install ffmpeg bc

# Arch Linux
sudo pacman -S ffmpeg bc

# macOS (via Homebrew)
brew install ffmpeg bc
```

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd pic2vid

# Make the script executable
chmod +x pic2vid.sh

# Run it
./pic2vid.sh --help
```

## Usage

### Basic Examples

```bash
# Create MP4 with default settings (3s per image)
./pic2vid.sh image1.jpg image2.jpg image3.jpg

# Create GIF animation
./pic2vid.sh -f gif -d 2 *.png

# Sort images by modification time
./pic2vid.sh -s mtime -d 3 ~/Photos/*.jpg

# Different duration for each image
./pic2vid.sh -d 1 2 3 4 img1.jpg img2.jpg img3.jpg img4.jpg

# Add metadata to output
./pic2vid.sh -m title="Vacation 2025" -m artist="John Doe" *.jpg
```

### Advanced Examples

```bash
# Complete workflow with all options
./pic2vid.sh -f mp4 \
  -s ctime \
  -d 2 2 2 5 \
  -o memories.mp4 \
  -m title="Summer Memories" \
  -m date="2025-08-15" \
  -m comment="Beach vacation" \
  photo1.jpg photo2.jpg photo3.jpg photo4.jpg

# Create GIF from sorted images
./pic2vid.sh -f gif -s name -d 1.5 -o animation.gif frames/*.png

# Use wildcards with automatic sorting
./pic2vid.sh -s mtime -o timeline.mp4 ~/Pictures/2025/*.jpg
```

## Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-d, --duration` | Duration in seconds (single value for all, or multiple for per-image) | `-d 3` or `-d 1 2 3` |
| `-o, --output` | Output filename | `-o myvideo.mp4` |
| `-s, --sort` | Sort images: `ctime`, `mtime`, `name`, `none` (default: none) | `-s mtime` |
| `-f, --format` | Output format: `mp4` or `gif` (default: mp4) | `-f gif` |
| `-m, --metadata` | Add metadata (can be used multiple times) | `-m title="My Video"` |
| `-h, --help` | Show help message | `--help` |

### Duration Options

```bash
# Single duration applies to all images
./pic2vid.sh -d 5 img1.jpg img2.jpg img3.jpg
# Result: 5s + 5s + 5s = 15s total

# Multiple durations must match number of images
./pic2vid.sh -d 1 1 1 4 img1.jpg img2.jpg img3.jpg img4.jpg
# Result: 1s + 1s + 1s + 4s = 7s total
```

### Sorting Options

```bash
# Sort by creation time (oldest first)
./pic2vid.sh -s ctime *.jpg

# Sort by modification time (oldest first)
./pic2vid.sh -s mtime *.jpg

# Sort alphabetically by filename
./pic2vid.sh -s name *.jpg

# No sorting (use shell expansion order)
./pic2vid.sh *.jpg
```

### Metadata Support

Add custom metadata tags that are embedded in the output file:

```bash
./pic2vid.sh \
  -m title="My Video Title" \
  -m artist="Creator Name" \
  -m date="2025-12-25" \
  -m comment="Video description" \
  -m copyright="© 2025" \
  *.jpg
```

The script automatically verifies that metadata was correctly embedded.

## Output Formats

### MP4 Video (Default)
- **Codec**: H.264 (libx264) with yuv420p pixel format
- **Audio**: AAC stereo at 128kbps (silent track for WhatsApp compatibility)
- **Optimization**: Fast start enabled for streaming
- **Target**: Under 16MB for WhatsApp sharing

### Animated GIF
- **Quality**: 256-color palette with dithering
- **Optimization**: Bayer dithering at scale 5 for smooth gradients
- **Size**: Typically larger than MP4 but universally compatible

## How It Works

1. **Dependency Check**: Validates ffmpeg, ffprobe, and bc are installed
2. **Input Validation**: Checks all image files exist
3. **Sorting** (if requested): Orders images by ctime/mtime/name
4. **Dimension Analysis**: Finds largest image dimensions (caps at 720px for WhatsApp)
5. **Segment Creation**: Each image becomes a video segment with proper scaling/padding
6. **Concatenation**: Merges segments with optional metadata
7. **Verification**: Confirms output duration matches expectations

### Adaptive Video Dimensions

The script analyzes all input images and uses the dimensions of the largest one (capped at 720px for WhatsApp compatibility). Smaller images are centered with black padding, maintaining aspect ratios without distortion.

## Output Information

After processing, the script displays:

```
✓ Video created successfully: output.mp4
  File size: 156KB
  Total duration: 12s

Metadata verification:
  ✓ title=Vacation 2025
  ✓ artist=John Doe
  ✓ comment=Summer memories
```

If there's a duration mismatch, you'll see:
```
⚠ Warning: Duration mismatch! Expected 12s, got 11s
```

## Supported Image Formats

All formats supported by ffmpeg:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- BMP (.bmp)
- TIFF (.tiff, .tif)
- WebP (.webp)
- And many more

## WhatsApp Compatibility

Videos are optimized for WhatsApp with:
- **Max Resolution**: 720px (auto-scaled)
- **Codec**: H.264 with yuv420p (required by WhatsApp)
- **Audio Track**: Silent AAC stereo (WhatsApp rejects videos without audio)
- **File Size Warning**: Alerts if output exceeds 16MB limit

### If File Size Exceeds 16MB

```bash
# Compress further manually
ffmpeg -i output.mp4 -c:v libx264 -crf 28 -c:a aac -b:a 96k output_compressed.mp4

# Or use fewer images / shorter durations
./pic2vid.sh -d 2 image1.jpg image2.jpg  # instead of -d 5
```

## Troubleshooting

### Missing Dependencies
The script automatically detects and shows installation commands for your distro.

### Images Not Sorted Correctly
- For chronological sorting, use `-s ctime` (creation) or `-s mtime` (modification)
- Use `-s name` for alphabetical ordering
- Verify file timestamps with `ls -lt` or `stat filename`

### Duration Mismatch Warning
Usually indicates an ffmpeg encoding issue. Try:
- Using whole numbers for durations instead of decimals
- Checking that all input images are valid
- Ensuring sufficient disk space

### Video Won't Play
- Ensure you're using the latest WhatsApp version
- Try re-encoding: `ffmpeg -i output.mp4 -c:v libx264 -pix_fmt yuv420p -c:a aac fixed.mp4`

### GIF File Too Large
GIFs are inherently larger than videos. Consider:
- Reducing duration per frame
- Using fewer images
- Switching to MP4 format for better compression

## License

This project is released into the public domain. Feel free to use, modify, and distribute as needed.

## Contributing

Contributions are welcome! Feel free to:
- Report bugs or request features via issues
- Submit pull requests with improvements
- Share your use cases and examples
