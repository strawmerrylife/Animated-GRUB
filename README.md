# GRUB Animation Project

Custom animated GRUB themes using the animation framework from [a1ive/grub](https://github.com/a1ive/grub).

GRUB Animation Project provides a simple workflow for creating animated GRUB themes from PNG animation frames, importing animations from ZIP archives, validating them, and building a standalone x86_64 UEFI GRUB image.

## Overview

The project is designed around a simple workflow:

```text
Animation ZIP
      ↓
Import animation
      ↓
Validate frames
      ↓
Detect frame count
      ↓
Generate GRUB configuration
      ↓
Build standalone EFI image
