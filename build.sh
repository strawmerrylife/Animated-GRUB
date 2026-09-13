#!/bin/bash
#
# build.sh - Builds a standalone x86_64 UEFI GRUB image with the
#            animation theme baked in.
#
# This script only ever reads from and writes to paths inside this
# repository (theme/, output/) plus a read-only check against the
# GRUB source tree. It never modifies GRUB source, GRUB build output,
# or any system bootloader files.
#
# Usage:
#   ./build.sh [--fps N] [GRUB_DIR]
#
#   --fps N     Play the animation at N frames per second (default: 10).
#               Converted internally to the milliseconds-per-frame value
#               a1ive's GRUB expects (grub_frame_speed).
#   GRUB_DIR    Path to your built a1ive GRUB source (default: one
#               directory above this project).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Argument parsing: --fps N (or --fps=N) plus an optional GRUB_DIR. -----
FPS=10
GRUB_DIR_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --fps)
            FPS="${2:-}"
            shift 2
            ;;
        --fps=*)
            FPS="${1#--fps=}"
            shift
            ;;
        -h|--help)
            echo "Usage: ./build.sh [--fps N] [GRUB_DIR]"
            echo
            echo "  --fps N     Animation playback speed in frames per second (default: 10)."
            echo "  GRUB_DIR    Path to your built a1ive GRUB source (default: ../ from this project)."
            exit 0
            ;;
        *)
            GRUB_DIR_ARG="$1"
            shift
            ;;
    esac
done

# Validate --fps: must be a positive integer GRUB can meaningfully use.
# Below 1 is meaningless. Above 60 is capped deliberately: a boot splash
# has no reason to run faster than typical display refresh rates, and
# very high FPS pushes ms/frame toward 0-1ms, which GRUB cannot render
# usefully.
if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [ "$FPS" -lt 1 ] || [ "$FPS" -gt 60 ]; then
    echo "ERROR: --fps must be a whole number between 1 and 60 (got: '$FPS')."
    echo "       Typical values: 10 (default), 15, 24, 30."
    exit 1
fi

# Convert FPS to milliseconds-per-frame (grub_frame_speed's actual unit),
# rounded to the nearest millisecond.
GRUB_FRAME_SPEED_MS=$(( (1000 + FPS / 2) / FPS ))

GRUB_DIR="${GRUB_DIR_ARG:-"$PROJECT_DIR/.."}"
BUILD_DIR="$GRUB_DIR/build"
THEME_DIR="$PROJECT_DIR/theme"
ANIMATION_DIR="$THEME_DIR/animation"
OUTPUT_DIR="$PROJECT_DIR/output"

# Path to the source file modified by fullscreen-animation.patch.
# Used only to verify (read-only) that the patch was applied before
# GRUB was compiled. We never write to this file.
PATCH_TARGET="$GRUB_DIR/grub-core/gfxmenu/animation/engine_core.c"
PATCH_MARKER="bind_menu != FULL_SCREEN_VARIETY"

echo "=== Animated GRUB Builder ==="
echo
echo "Animation speed: $FPS FPS ($GRUB_FRAME_SPEED_MS ms/frame)"
echo

# --- Step 1: Validate animation frames first. -----------------------------
"$PROJECT_DIR/validate.sh"

# --- Step 2: Detect frame count (robust to find/wc pipeline failures). ----
mapfile -t FRAME_FILES < <(find "$ANIMATION_DIR" -maxdepth 1 -type f -name '*.png')
FRAME_COUNT="${#FRAME_FILES[@]}"

if [ "$FRAME_COUNT" -eq 0 ]; then
    echo "ERROR: No animation frames found in:"
    echo "  $ANIMATION_DIR"
    exit 1
fi

echo
echo "Detected frame count: $FRAME_COUNT"
echo

# --- Step 3: Make sure the GRUB build exists. ------------------------------
if [ ! -x "$BUILD_DIR/grub-mkstandalone" ]; then
    echo "ERROR: GRUB build tools were not found."
    echo "Expected:"
    echo "  $BUILD_DIR/grub-mkstandalone"
    echo
    echo "Build a1ive/grub first (see README.md), then re-run this script."
    exit 1
fi

# --- Step 4: Verify the fullscreen-animation patch was applied. -----------
# This is a READ-ONLY check. We never modify GRUB source from here.
# The patch must be applied to the GRUB source tree and GRUB must be
# rebuilt BEFORE running this script - applying it now would be too
# late (grub-mkstandalone above is already compiled) and would mean
# editing files outside this repository, which this project does not do.
if [ -f "$PATCH_TARGET" ]; then
    if grep -qF "$PATCH_MARKER" "$PATCH_TARGET"; then
        echo "✓ fullscreen-animation.patch appears applied to GRUB source."
    else
        if [ "${ALLOW_UNPATCHED_GRUB:-0}" = "1" ]; then
            echo "WARNING: fullscreen-animation.patch does NOT appear applied."
            echo "         Continuing anyway because ALLOW_UNPATCHED_GRUB=1 is set."
            echo "         The built image may drop out of full-screen animation"
            echo "         mode when a menu item is selected."
        else
            echo "ERROR: fullscreen-animation.patch does not appear to be applied"
            echo "       to your GRUB source at:"
            echo "         $PATCH_TARGET"
            echo
            echo "Without it, GRUB's own animation engine will interrupt the"
            echo "animation whenever the menu selection changes - the image will"
            echo "still build, but full-screen playback will be broken."
            echo
            echo "To fix this:"
            echo "  1. cd \"$GRUB_DIR\""
            echo "  2. git apply \"$PROJECT_DIR/fullscreen-animation.patch\""
            echo "  3. Rebuild GRUB (re-run its configure/make, or your usual build steps)"
            echo "  4. Re-run this script"
            echo
            echo "If you have already patched a differently-laid-out GRUB source"
            echo "and are sure this check is a false positive, re-run with:"
            echo "  ALLOW_UNPATCHED_GRUB=1 ./build.sh"
            exit 1
        fi
    fi
else
    echo "NOTE: Could not find $PATCH_TARGET to verify the patch."
    echo "      Skipping the patch check - make sure you applied"
    echo "      fullscreen-animation.patch to your GRUB source and rebuilt"
    echo "      GRUB before running this script."
fi
echo

# --- Step 5: Clean and recreate the output directory. ----------------------
# Prevents stale files from a previous (possibly failed) build from
# lingering and being mistaken for the current output.
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# --- Step 6: Generate theme with the detected frame count. -----------------
GENERATED_THEME="$OUTPUT_DIR/theme.txt"

cat > "$GENERATED_THEME" <<EOF
# Animated GRUB

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

# --- Step 7: Generate GRUB configuration. -----------------------------------
GENERATED_CFG="$OUTPUT_DIR/grub.cfg"

cat > "$GENERATED_CFG" <<EOF
set grub_frame_speed=$GRUB_FRAME_SPEED_MS
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

# --- Step 8: Build standalone GRUB EFI. -------------------------------------
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
