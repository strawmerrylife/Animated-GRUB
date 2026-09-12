#!/bin/bash

set -e

ANIMATION_DIR="$(dirname "$0")/theme/animation"

echo "=== GRUB Animation Validator ==="
echo

if [ ! -d "$ANIMATION_DIR" ]; then
    echo "ERROR: Animation directory not found:"
    echo "$ANIMATION_DIR"
    exit 1
fi

files=("$ANIMATION_DIR"/*.png)

if [ ! -e "${files[0]}" ]; then
    echo "ERROR: No PNG frames found."
    exit 1
fi

count=${#files[@]}

echo "Found $count PNG frame(s)."
echo

# Check filenames and PNG validity.
for file in "${files[@]}"; do
    name="$(basename "$file" .png)"

    if ! [[ "$name" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid frame filename: $(basename "$file")"
        echo "       Frames must be named 1.png, 2.png, 3.png, ..."
        exit 1
    fi

    if ! file "$file" | grep -q "PNG image data"; then
        echo "ERROR: File is not a valid PNG:"
        echo "       $(basename "$file")"
        exit 1
    fi
done

# Check sequential numbering.
expected=1

while [ "$expected" -le "$count" ]; do
    if [ ! -f "$ANIMATION_DIR/$expected.png" ]; then
        echo "ERROR: Missing frame: $expected.png"
        exit 1
    fi

    expected=$((expected + 1))
done

# Check that all frames have the same dimensions.
first_info="$(file "$ANIMATION_DIR/1.png")"

first_dimensions="$(echo "$first_info" | sed -n 's/.*PNG image data, \([0-9]* x [0-9]*\).*/\1/p')"

if [ -z "$first_dimensions" ]; then
    echo "ERROR: Could not determine dimensions of 1.png"
    exit 1
fi

for file in "${files[@]}"; do
    dimensions="$(file "$file" | sed -n 's/.*PNG image data, \([0-9]* x [0-9]*\).*/\1/p')"

    if [ "$dimensions" != "$first_dimensions" ]; then
        echo "ERROR: Frame dimensions do not match:"
        echo "       $(basename "$file"): $dimensions"
        echo "       Expected: $first_dimensions"
        exit 1
    fi
done

echo "✓ Frame numbering is complete: 1.png -> $count.png"
echo "✓ All frames are valid PNG files"
echo "✓ All frames have matching dimensions: $first_dimensions"
echo
echo "Animation validation successful!"
echo "Frame count: $count"
