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
  image_format = png
  size_ratio = 1
  frame_number = $FRAME_COUNT
  move_speed = 0
  play_once = pause
  bind_menu = full_screen
}

+ boot_menu {
  left = 7%+3
  top = 86%-161
  width = 600
  height = 143
  item_height = 32
  item_font = "Funnel Sans Regular 21"
  item_color = "#ACA8A5"
  item_padding = 0
  icon_width = 19
  item_icon_space = 18
  icon_height = 0
  selected_item_color = "#FFFFFF"
  selected_item_font = "Funnel Sans Regular 21"
  item_spacing = 4
  selected_item_pixmap_style = "selected_item_*.png"
}

+ label {
  color = "#ACA8A5"
  font = "Funnel Sans Regular 21"
  left = 9%+3
  top = 87%+1
  width = 31%
  align = "left"
  text = "Press C for Console or E to Edit"
}

+ label {
  color = "#ACA8A5"
  font = "Funnel Sans Regular 22"
  left = 85%+1
  top = 87%+5
  width = 31%
  align = "left"
  text = "Booting"
}

+ label {
  color = "#5AEB71"
  font = "Teko Regular 32"
  left = 85%+112
  top = 87%
  width = 31%
  align = "left"
  id = "__timeout__"
  text = "%d"
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
    "boot/grub/animation=$ANIMATION_DIR"

echo
echo "=== Build successful ==="
echo
echo "Output:"
echo "  $OUTPUT_DIR/grub-animation-x86_64.efi"
