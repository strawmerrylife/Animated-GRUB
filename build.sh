#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRUB_DIR="${1:-"$PROJECT_DIR/.."}"
BUILD_DIR="$GRUB_DIR/build"
THEME_DIR="$PROJECT_DIR/theme"
ANIMATION_DIR="$THEME_DIR/animation"
OUTPUT_DIR="$PROJECT_DIR/output"

echo "=== GRUB Animation Builder ==="
echo

# Validate animation frames first.
"$PROJECT_DIR/validate.sh"

# Count frames.
FRAME_COUNT=$(find "$ANIMATION_DIR" -maxdepth 1 -type f -name '*.png' | wc -l)

echo
echo "Detected frame count: $FRAME_COUNT"
echo

# Make sure the GRUB build exists.
if [ ! -x "$BUILD_DIR/grub-mkstandalone" ]; then
    echo "ERROR: GRUB build tools were not found."
    echo "Expected:"
    echo "$BUILD_DIR/grub-mkstandalone"
    exit 1
fi

# Create output directory.
mkdir -p "$OUTPUT_DIR"

# Generate theme with the detected frame count.
GENERATED_THEME="$OUTPUT_DIR/theme.txt"

cat > "$GENERATED_THEME" <<EOF
# GRUB Animation Project

+ animation {
    dir_name = "animation"
    image_format = "png"
    frame_number = $FRAME_COUNT
    bind_menu = "full_screen"
}
EOF

# Generate GRUB configuration.
GENERATED_CFG="$OUTPUT_DIR/grub.cfg"

cat > "$GENERATED_CFG" <<EOF
set grub_frame_speed=100
set gfxmode=auto
set gfxpayload=keep

insmod gfxterm
insmod gfxmenu

terminal_output gfxterm

set theme=/boot/grub/themes/animation/theme.txt
export theme

normal
EOF

echo "Generated theme:"
echo "  $GENERATED_THEME"
echo
echo "Generated config:"
echo "  $GENERATED_CFG"
echo

# Build standalone GRUB EFI.
"$BUILD_DIR/grub-mkstandalone" \
    -O x86_64-efi \
    --directory="$BUILD_DIR/grub-core" \
    -o "$OUTPUT_DIR/grub-animation-x86_64.efi" \
    --modules="all_video gfxterm gfxmenu png font" \
    "boot/grub/grub.cfg=$GENERATED_CFG" \
    "boot/grub/themes/animation/theme.txt=$GENERATED_THEME" \
    "boot/grub/themes/animation/animation=$ANIMATION_DIR"

echo
echo "=== Build successful ==="
echo
echo "Output:"
echo "  $OUTPUT_DIR/grub-animation-x86_64.efi"
