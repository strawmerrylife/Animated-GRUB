# GRUB Animation Project

A custom animated GRUB theme using the animated GRUB framework from [a1ive/grub](https://github.com/a1ive/grub).

This project lets you use a sequence of numbered PNG frames as a fullscreen GRUB animation.

## Features

- Fullscreen animated GRUB background
- Supports numbered PNG frames
- Automatically detects the number of animation frames
- Validates frame numbering before building
- Builds a standalone x86_64 UEFI GRUB image
- Keeps generated build files out of the repository
- Does not automatically modify your system's GRUB installation

## Project Structure

```text
grub-animation-project/
├── .gitignore
├── README.md
├── build.sh
├── validate.sh
└── theme/
    ├── theme.txt
    └── animation/
        ├── 1.png
        ├── 2.png
        ├── 3.png
        └── ...
