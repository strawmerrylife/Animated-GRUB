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

expected=1

for file in "${files[@]}"; do
    name="$(basename "$file" .png)"

    if ! [[ "$name" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid frame filename: $(basename "$file")"
        echo "       Frames must be named 1.png, 2.png, 3.png, ..."
        exit 1
    fi
done

while [ "$expected" -le "$count" ]; do
    if [ ! -f "$ANIMATION_DIR/$expected.png" ]; then
        echo "ERROR: Missing frame: $expected.png"
        exit 1
    fi

    expected=$((expected + 1))
done

echo "✓ Frame numbering is complete: 1.png -> $count.png"
echo
echo "Animation validation successful!"
echo "Frame count: $count"

