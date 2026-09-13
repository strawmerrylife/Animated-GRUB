# Animated GRUB

Create custom animated GRUB boot screens from PNG animation frames.

Animated GRUB validates your frames, automatically detects the frame count, generates the required GRUB theme and configuration, and builds a standalone x86_64 UEFI GRUB image.

> **Repository:** `grub-animation-project`  
> **Project name:** Animated GRUB

## Preview

The repository includes a 300-frame example animation in:

```text
theme/animation/
```

---

A visual preview of the animated GRUB background and menu UI.

---

## Quick Start

### 1. Install dependencies

On Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y git build-essential bison flex autoconf automake \
    libtool pkg-config python3 autopoint texinfo unzip file
```

### 2. Clone Animated GRUB and a1ive GRUB

Keep both repositories next to each other:

```bash
mkdir -p ~/grub-animation-workspace
cd ~/grub-animation-workspace

git clone https://github.com/strawmerrylife/Animated-GRUB.git
git clone https://github.com/a1ive/grub.git
```

### 3. Apply the animation patch

```bash
cd ~/grub-animation-workspace/grub
git apply ../Animated-GRUB/fullscreen-animation.patch
```

### 4. Build a1ive GRUB

```bash
./bootstrap
./autogen.sh
mkdir -p build
cd build

../configure --target=x86_64 --with-platform=efi --disable-werror
make
```

`./bootstrap` is required because a1ive GRUB uses an internal `gnulib` checkout.

`--disable-werror` is recommended on modern GCC versions because older GRUB code can trigger compiler warnings that would otherwise be treated as build errors.

The build can take several minutes and may require more than 1 GB of disk space.

### 5. Add your animation

You can either import a ZIP:

```bash
cd ~/grub-animation-workspace/Animated-GRUB
./install-animation.sh /path/to/animation.zip
```

Or copy already-numbered frames manually:

```bash
cp /path/to/frames/*.png theme/animation/
```

The final frames must be named:

```text
1.png
2.png
3.png
...
```

### 6. Validate and build

```bash
./validate.sh
./build.sh
```

The resulting EFI image will be:

```text
output/grub-animation-x86_64.efi
```

---

## Adding Animation Frames

### ZIP import

`install-animation.sh` accepts ZIP files containing PNG frames.

The importer:

- finds PNG files recursively,
- accepts arbitrary original filenames,
- sorts the frames naturally,
- verifies that every file is a real PNG,
- verifies that all frames have matching dimensions,
- renames them sequentially as `1.png`, `2.png`, `3.png`, etc.

All validation happens **before** the existing animation is replaced. If the ZIP is invalid, your current animation is left untouched.

### Manual frame copying

If you copy frames yourself, make sure they use lowercase `.png` extensions:

```text
1.png
2.png
3.png
```

`validate.sh` expects the lowercase extension and sequential numbering.

---

## Frame Requirements

Every frame must:

- be a genuine PNG,
- use a lowercase `.png` extension,
- have a sequential numeric filename,
- start at `1.png`,
- contain no gaps,
- have the same width and height as every other frame.

Run:

```bash
./validate.sh
```

to check everything automatically.

---

## Animation Speed

`build.sh` supports a simple FPS option:

```bash
./build.sh --fps 24
```

For example:

```bash
./build.sh --fps 30
```

The accepted range is **1–60 FPS**.

The default is **10 FPS**.

You can also specify a custom a1ive GRUB directory:

```bash
./build.sh --fps 30 /path/to/grub
```

The script converts FPS into the millisecond-per-frame value required by a1ive GRUB automatically.

---

## Build Output

A successful build creates:

```text
output/
├── theme.txt
├── grub.cfg
└── grub-animation-x86_64.efi
```

`build.sh` regenerates the output directory each time it runs.

The generated EFI file is a standalone x86_64 UEFI GRUB image containing the animation and generated theme.

---

## How It Works

The workflow is:

```text
PNG frames / ZIP
       ↓
install-animation.sh
       ↓
validate.sh
       ↓
Frame count detected
       ↓
GRUB theme + grub.cfg generated
       ↓
grub-mkstandalone
       ↓
output/grub-animation-x86_64.efi
```

The project uses the animation framework from [a1ive/grub](https://github.com/a1ive/grub).

`fullscreen-animation.patch` modifies two parts of that framework so the animation can remain full-screen and is not interrupted by menu selection changes.

---

## Bootloader Safety

**Animated GRUB does not install itself onto your computer.**

The project's scripts:

- only write inside this repository,
- only read the separate GRUB source/build directory,
- do not modify `/boot`,
- do not modify the EFI System Partition,
- do not modify `/etc/default/grub`,
- do not modify `/etc/grub.d`,
- do not run `grub-install`,
- do not run `update-grub`.

`build.sh` produces an EFI file inside `output/`. It does **not** install that file.

### Important

Deploying the generated EFI image to real boot media is a separate, manual operation.

Changing your system's EFI or bootloader configuration can affect whether your computer boots. Make sure you understand your system's boot setup and have a recovery method before deploying anything.

---

## Troubleshooting

### `Gnulib not yet bootstrapped`

Run:

```bash
./bootstrap
```

before:

```bash
./autogen.sh
```

### `autopoint: not found`

Install:

```bash
sudo apt install -y autopoint
```

### `dangling-pointer` / `-Werror` during `make`

Reconfigure GRUB with:

```bash
../configure --target=x86_64 --with-platform=efi --disable-werror
```

then run:

```bash
make
```

### `No PNG frames found`

Make sure `theme/animation/` contains lowercase `.png` files.

### `Invalid frame filename`

Frames must use names such as:

```text
1.png
2.png
3.png
```

### `Missing frame`

There must be no gaps in the numbering.

### `Frame dimensions do not match`

Every frame must have exactly the same width and height.

### `fullscreen-animation.patch does not appear to be applied`

Apply the patch to the a1ive GRUB source:

```bash
git apply ../Animated-GRUB/fullscreen-animation.patch
```

Then rebuild GRUB.

`build.sh` checks the GRUB **source files** for the patch. It cannot determine whether the patched source was actually recompiled afterward, so always rebuild after applying the patch.

### Invalid FPS

Use a whole number between 1 and 60:

```bash
./build.sh --fps 24
```

---

## Credits

- **[a1ive/grub](https://github.com/a1ive/grub)** — provides the GRUB animation framework used by this project.
- **`fullscreen-animation.patch`** — project patch modifying the a1ive GRUB animation/menu code for full-screen animation playback.
- **OpenAI / ChatGPT** — assisted with project planning, debugging, documentation, workflow design, and general development guidance.
- **Claude / Anthropic** — assisted with reviewing, improving, and editing the project's scripts and documentation, including validation and safety improvements.

The generated theme references **Funnel Sans** and **Teko** for its menu and label typography. These fonts are not bundled with this repository and must be available to the GRUB build separately.

See `LICENSE` and `NOTICE` for additional licensing and attribution information.
