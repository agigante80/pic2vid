# Copilot Instructions for pic2vid

## Project Overview
Single-purpose bash script that converts image sequences to WhatsApp-compatible MP4 videos using ffmpeg. Focus is on compatibility, file size optimization, and user-friendly CLI.

## Core Architecture
- **Main script**: [pic2vid.sh](../pic2vid.sh) - Self-contained bash script with no external dependencies beyond ffmpeg
- **Processing pipeline**: Individual image → scaled video segment → concatenated final video with audio track
- **Temporary workspace**: Uses `mktemp -d` with EXIT trap for cleanup

## WhatsApp Video Requirements (Critical)
All video output must meet these specs:
- **Codec**: H.264 video (`libx264`), AAC audio
- **Pixel format**: `yuv420p` (required for WhatsApp compatibility)
- **Resolution**: Max 720px, square format (720x720) with black padding
- **Audio**: Silent stereo track at 44.1kHz (WhatsApp rejects videos without audio)
- **File size**: Target under 16MB, warn users if exceeded
- **Streaming**: Include `-movflags +faststart` for quick playback

## Key Technical Decisions

### Image Processing Pattern
Each image becomes a video segment using:
```bash
ffmpeg -loop 1 -i "$img" -vf "scale='min(720,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,pad=720:720:(ow-iw)/2:(oh-ih)/2:black" \
    -c:v libx264 -t "$DURATION" -pix_fmt yuv420p -r 25 \
    "$TEMP_DIR/segment_$(printf "%03d" $i).mp4"
```
- Scale maintains aspect ratio, never exceeds 720px
- Pad centers image on 720x720 black canvas
- 25fps for smooth playback

### Concatenation Strategy
Uses ffmpeg concat demuxer with file list rather than complex filter graphs for reliability and memory efficiency with many images.

## CLI Conventions
- **Positional args**: Image files (supports wildcards via shell expansion)
- **Options**: Use both short (`-d`) and long (`--duration`) forms
- **Defaults**: 3s per image, `output.mp4` filename
- **Error handling**: Early validation with clear error messages before processing

## Development Workflows

### Testing Changes
```bash
# Test with 2-3 small images to iterate quickly
./pic2vid.sh -d 1 test1.jpg test2.jpg

# Test edge cases
./pic2vid.sh -d 2 portrait.jpg landscape.jpg square.jpg
./pic2vid.sh huge_image.jpg  # Test large file handling
```

### Debugging ffmpeg Issues
- Script uses `-loglevel error` to suppress verbose output
- For debugging, temporarily change to `-loglevel verbose` or remove flag
- Check intermediate segments in temp dir: comment out `trap "rm -rf $TEMP_DIR" EXIT`

### File Size Optimization
Current compression: `-preset medium -crf 23 -b:a 128k`
- Lower CRF = higher quality/size (18-28 range typical)
- Preset affects encoding speed vs compression efficiency
- Audio bitrate can drop to 96k if needed

## Platform-Specific Considerations
- File size stat command has OS variations: `stat -f%z` (BSD/macOS) vs `stat -c%s` (GNU/Linux)
- Use `command -v` for dependency checks (more portable than `which`)
- Ensure POSIX compatibility where possible for broader Linux distribution support

## When Modifying
- **Preserve WhatsApp compatibility**: Always test output plays in WhatsApp
- **Maintain single-file simplicity**: Don't split into multiple scripts unless absolutely necessary
- **Keep dependencies minimal**: Only ffmpeg required, no Python/Node/etc.
- **Provide compression guidance**: If adding features that increase file size, include compression recommendations
