#!/bin/bash

set -euo pipefail

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

echo "=== Animated GRUB Importer ==="
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

# Validate every file BEFORE touching theme/animation/, so any error
# message can point back to the original filename from the ZIP instead
# of a confusing renamed "N.png", and so a failed import never deletes
# or replaces a previously-working animation.
for file in "${PNG_FILES[@]}"; do
    if ! file "$file" | grep -q "PNG image data"; then
        echo "ERROR: Not a valid PNG file in the ZIP:"
        echo "       $(basename "$file")"
        echo
        echo "Your existing animation has NOT been changed."
        exit 1
    fi
done

echo "All source files are valid PNGs."
echo

# Check that every frame has the same dimensions as the first frame,
# BEFORE touching theme/animation/. This uses the same "file"-based
# dimension check as validate.sh, but against the original filenames
# in the ZIP so a mismatch is easy to trace back to its source.
first_info="$(file "${PNG_FILES[0]}")"
first_dimensions="$(echo "$first_info" | sed -n 's/.*PNG image data, \([0-9]* x [0-9]*\).*/\1/p')"

if [ -z "$first_dimensions" ]; then
    echo "ERROR: Could not determine dimensions of:"
    echo "       $(basename "${PNG_FILES[0]}")"
    echo
    echo "Your existing animation has NOT been changed."
    exit 1
fi

for file in "${PNG_FILES[@]}"; do
    dimensions="$(file "$file" | sed -n 's/.*PNG image data, \([0-9]* x [0-9]*\).*/\1/p')"

    if [ "$dimensions" != "$first_dimensions" ]; then
        echo "ERROR: Frame dimensions do not match:"
        echo "       $(basename "$file"): $dimensions"
        echo "       Expected: $first_dimensions"
        echo
        echo "Your existing animation has NOT been changed."
        exit 1
    fi
done

echo "All source frames match dimensions: $first_dimensions"
echo

# Only now that every check has passed do we touch theme/animation/.

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

# Final confirmation pass (numbering, format, dimensions) on the
# frames actually written to theme/animation/. Since every check
# above already passed against the same source files, this is a
# safety net rather than an expected point of failure.
"$PROJECT_DIR/validate.sh"

echo
echo "Animation import successful!"
echo
echo "You can now build with:"
echo "  ./build.sh"
