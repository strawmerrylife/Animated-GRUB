#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANIMATION_DIR="$PROJECT_DIR/theme/animation"
ZIP_FILE="$1"

if [ -z "$ZIP_FILE" ]; then
    echo "Usage: ./install-animation.sh animation.zip"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "ERROR: ZIP file not found:"
    echo "$ZIP_FILE"
    exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== GRUB Animation Importer ==="
echo
echo "ZIP: $ZIP_FILE"
echo

unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

mapfile -t PNG_FILES < <(find "$TEMP_DIR" -type f -iname '*.png' | sort -V)

if [ "${#PNG_FILES[@]}" -eq 0 ]; then
    echo "ERROR: No PNG files found in the ZIP."
    exit 1
fi

echo "Found ${#PNG_FILES[@]} PNG frame(s)."
echo

# Clear existing animation frames.
rm -f "$ANIMATION_DIR"/*.png

# Copy and normalize filenames.
frame=1

for file in "${PNG_FILES[@]}"; do
    cp "$file" "$ANIMATION_DIR/$frame.png"
    frame=$((frame + 1))
done

echo "Imported ${#PNG_FILES[@]} frame(s)."
echo

# Validate the imported animation.
"$PROJECT_DIR/validate.sh"

echo
echo "Animation import successful!"
echo
echo "You can now build with:"
echo "  ./build.sh"
