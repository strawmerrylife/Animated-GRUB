# Animated GRUB

Custom animated GRUB themes using the animation framework from [a1ive/grub](https://github.com/a1ive/grub).

> This project's GitHub repository is currently named `grub-animation-project` — all clone/folder paths in this README use that name. "Animated GRUB" is the project's display name.

## 1. What this project is

Animated GRUB is a set of shell scripts and a theme template that turn a sequence of PNG frames into an animated splash screen for GRUB, and package the result as a **standalone x86_64 UEFI GRUB image** (a single `.efi` file).

Concretely, this repository:

- accepts animation frames as either a folder of numbered PNGs or a ZIP archive,
- automatically detects how many frames you have,
- validates frame naming, PNG format, and dimensions,
- generates the GRUB theme (`theme.txt`) and boot config (`grub.cfg`) to match your animation,
- packages everything and calls `grub-mkstandalone` to produce `output/grub-animation-x86_64.efi`.

**What this project does *not* do:** it does not install, register, or activate anything as your system bootloader. It never touches `/boot`, your EFI System Partition, `/etc/default/grub`, and never runs `grub-install` or `update-grub`. See [Bootloader safety](#13-bootloader-safety) below — this matters and is explained in detail.

```text
Animation ZIP or PNG folder
      ↓
Import / place frames (install-animation.sh)
      ↓
Validate frames (validate.sh)
      ↓
Detect frame count
      ↓
Generate GRUB theme + config
      ↓
Build standalone EFI image (build.sh)
      ↓
output/grub-animation-x86_64.efi
```

---

## Quick start (experienced users)

```bash
# 1. Get, bootstrap, and patch a1ive GRUB, next to this repo, then build it
git clone https://github.com/a1ive/grub.git
cd grub
./bootstrap
git apply ../grub-animation-project/fullscreen-animation.patch
./autogen.sh && mkdir build && cd build
../configure --target=x86_64 --with-platform=efi --disable-werror && make
cd ../..

# 2. Add your frames (ZIP or folder of 1.png, 2.png, ...)
cd grub-animation-project
./install-animation.sh /path/to/animation.zip
# — or —
cp /path/to/frames/*.png theme/animation/

# 3. Build (defaults to 10 FPS; pass --fps to change it)
./build.sh --fps 24
# Output: output/grub-animation-x86_64.efi
```

If you're not already comfortable with GRUB/EFI internals, skip to the full walkthrough below.

---

## 2. Prerequisites

You need a Linux machine (a virtual machine is fine) with:

- `git`
- A C toolchain and GRUB's own build dependencies: `build-essential`, `bison`, `flex`, `autoconf`, `automake`, `libtool`, `pkg-config`, `python3`, `autopoint`, `texinfo`
- `unzip` and `file` (used by this project's own scripts)

On Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y git build-essential bison flex autoconf automake \
    libtool pkg-config python3 autopoint texinfo unzip file
```

> **Note:** `autopoint` and `texinfo` are easy to miss — on Ubuntu/Debian, `autopoint` is a separate package from `gettext` even though it's part of the same upstream project, and GRUB's `./bootstrap` step (below) needs it directly. Skipping it produces an `autopoint: not found` error partway through bootstrapping.

On other distributions, install the equivalent packages with your package manager — the key ones are a C compiler, `make`, `bison`, `flex`, `autoconf`/`automake`, `unzip`, and your distro's `gettext`/`autopoint` and `texinfo` packages.

You will also need your animation, as either:

- a folder of numbered PNG frames (`1.png`, `2.png`, `3.png`, ...), or
- a ZIP file containing PNG frames (any filenames — the importer renumbers them for you).

**Budget some disk space and time for the next few steps:** building a1ive GRUB from source, including a one-time internal `gnulib` checkout (roughly 500MB by itself), comfortably exceeds 1GB of disk space and can take 15–40 minutes depending on your machine, separate from anything in this project.

---

## 3. Clone this repository

Pick a workspace folder to hold both this project and the GRUB source side by side:

```bash
mkdir -p ~/grub-animation-workspace
cd ~/grub-animation-workspace
git clone https://github.com/strawmerrylife/grub-animation-project.git
```

---

## 4. Obtain the a1ive GRUB source

This project builds *on top of* a1ive's GRUB fork — it does not include GRUB itself. Clone it **next to** (not inside) this project, because the build script defaults to looking for GRUB one directory above itself:

```bash
cd ~/grub-animation-workspace
git clone https://github.com/a1ive/grub.git
```

Your folder layout should now look like:

```text
~/grub-animation-workspace/
├── grub/                       <- a1ive's GRUB source
└── grub-animation-project/     <- this project
```

---

## 5. Apply `fullscreen-animation.patch`

This patch must be applied to the GRUB source **before** you compile it. It changes two things in GRUB's own animation/menu engine:

- `grub-core/gfxmenu/animation/engine_core.c` — stops the animation from being interrupted when the menu selection changes, so it plays full-screen as intended.
- `grub-core/gfxmenu/gui_canvas.c` — changes how GUI components are ordered internally so the animation layer and menu/labels draw in the correct order.

Apply it from inside the GRUB source directory:

```bash
cd ~/grub-animation-workspace/grub
git apply ../grub-animation-project/fullscreen-animation.patch
```

If `git apply` reports an error, your GRUB checkout may be at a different commit than the patch was written against — check for `.rej` files and resolve conflicts manually before continuing.

> **Important:** always rebuild GRUB (step 6) immediately after applying this patch, before running this project's `build.sh`. `build.sh`'s patch check only inspects GRUB's *source file* for the patch text — it cannot see whether the compiled binary/modules were actually rebuilt afterward. If you apply the patch but forget to rebuild, the check will still report "patch appears applied" (because the source *is* patched) even though the compiled output you're about to package is not.

---

## 6. Compile a1ive GRUB

Still inside the GRUB source directory, first bootstrap the build system — this is a one-time step that fetches GRUB's internal `gnulib` support library and generates its build scripts:

```bash
./bootstrap
```

This step alone can take several minutes and roughly 500MB of disk space (it clones `gnulib` from GitHub). **This step is required** — skipping straight to `./autogen.sh` will fail immediately with `Gnulib not yet bootstrapped; run ./bootstrap instead.`, since `autogen.sh` depends on files `./bootstrap` generates.

Once that finishes, continue with the normal build:

```bash
./autogen.sh
mkdir -p build
cd build
../configure --target=x86_64 --with-platform=efi --disable-werror
make
```

> **About `--disable-werror`:** on newer compilers (for example, GCC 12+ / Ubuntu 22.04 and later), GRUB's own source can fail to compile with an error like `dangling pointer to 'tmp_' may be used [-Werror=dangling-pointer=]`. This is old code tripping a newer compiler warning that GRUB's build treats as fatal by default. `--disable-werror` tells GRUB to treat these as warnings instead of build-stopping errors, and is included above so the documented command works out of the box. If you're on an older toolchain where this was never an issue, it's harmless to include either way.

This step can take 10–30 minutes. When it finishes, you should have a working binary at:

```text
~/grub-animation-workspace/grub/build/grub-mkstandalone
```

This is the tool `build.sh` calls later — you never run it directly, and this project never modifies it or the GRUB source tree.

> If any of these GRUB build commands fail with something other than the two issues above, that's a GRUB compilation issue specific to your system, not something this project's scripts control. Check a1ive/grub's own README and issue tracker for platform-specific build dependencies.

---

## 7. Add and customize your animation frames

Go back to this project's directory:

```bash
cd ~/grub-animation-workspace/grub-animation-project
```

You have two ways to provide frames:

**Option A — import a ZIP:**

```bash
./install-animation.sh /path/to/your-animation.zip
```

This unzips the archive, checks every file is really a PNG **and** that every frame's dimensions match, sorts the frames (numerically, if filenames contain numbers), and only then copies them into `theme/animation/` renamed to `1.png`, `2.png`, `3.png`, ... in order — replacing whatever was there before. If any frame fails a check, the import stops immediately and **your existing animation is left completely untouched**; nothing is deleted or replaced until every frame in the new ZIP has passed validation.

**Option B — copy a folder of frames directly:**

```bash
rm -f theme/animation/*.png
cp /path/to/your/frames/*.png theme/animation/
```

With this option, you are responsible for naming and ordering the files yourself (see requirements below) — `install-animation.sh` is not involved.

Whenever you want to change the animation later, repeat this step with your new frames and rebuild (step 10) — there is no separate "update" command, the same import/build steps are used every time.

---

## 8. Animation frame requirements

Whichever method you use, the final frames in `theme/animation/` must satisfy all of the following, which `validate.sh` enforces:

- **Format:** every frame must be a genuine PNG file (checked by content, not just the `.png` extension).
- **Naming:** frames must be named as plain sequential integers with a **lowercase** `.png` extension and no leading zeros or extra characters: `1.png`, `2.png`, `3.png`, ... up to however many frames you have. `install-animation.sh` (Option A) always produces lowercase filenames for you; if you're copying files in manually (Option B), an uppercase extension like `1.PNG` will not be recognized — `validate.sh`'s file matching is case-sensitive on Linux, so such files are silently skipped rather than flagged with a helpful error, which can otherwise look like "no frames found" for no obvious reason.
- **Completeness:** numbering must be contiguous starting at `1.png` with no gaps (e.g. you cannot have `1.png`, `2.png`, `4.png` with `3.png` missing).
- **Dimensions:** every frame must have the exact same pixel width and height as `1.png`.

The frame count itself is not fixed — `build.sh` detects it automatically and writes it into the generated theme, so you can use any number of frames.

---

## 9. Run validation

`build.sh` always validates before building, but you can run it standalone at any time:

```bash
./validate.sh
```

A successful run looks like:

```text
=== Animated GRUB Validator ===

Found 300 PNG frame(s).

✓ Frame numbering is complete: 1.png -> 300.png
✓ All frames are valid PNG files
✓ All frames have matching dimensions: 960 x 540

Animation validation successful!
Frame count: 300
```

See [Troubleshooting](#troubleshooting) for what each possible error means and how to fix it.

---

## 10. Build the standalone EFI image

```bash
./build.sh
```

By default, `build.sh` looks for your built GRUB one directory above this project (`../grub`, i.e. `~/grub-animation-workspace/grub` in this walkthrough) and plays the animation at **10 frames per second**. If your GRUB source lives somewhere else, pass its path explicitly:

```bash
./build.sh /path/to/your/grub
```

### Customizing the animation speed (FPS)

Use `--fps` to change playback speed, as a plain frames-per-second number:

```bash
./build.sh --fps 24
```

You can combine it with a custom GRUB path (order doesn't matter):

```bash
./build.sh --fps 30 /path/to/your/grub
```

Behind the scenes, a1ive's GRUB doesn't actually take an FPS value — it uses a variable called `grub_frame_speed`, measured in **milliseconds per frame**. `build.sh` converts your `--fps` value to the correct milliseconds figure automatically (for example, `--fps 24` becomes roughly 42 milliseconds/frame), so you never need to do that conversion yourself. Accepted range is 1–60; the default (if you don't pass `--fps` at all) is 10, matching this project's previous fixed behavior.

`build.sh` will, in order: validate your frames, detect the frame count, confirm `grub-mkstandalone` exists, verify (read-only) that `fullscreen-animation.patch` looks applied to your GRUB source, generate the theme and config (using your chosen speed), and finally call `grub-mkstandalone` to produce the image.

Repeat this step (and step 7, if you changed frames) any time you want to rebuild — `build.sh` clears and regenerates its output directory on every run, so there is no manual cleanup needed between builds.

---

## 11. Generated files and their locations

After a successful build, everything produced lives under `output/` inside this repository:

| File | Purpose |
|---|---|
| `output/theme.txt` | The generated GRUB theme, including your detected frame count, animation settings, boot menu layout, and on-screen labels. |
| `output/grub.cfg` | The generated GRUB configuration that loads the graphics terminal, sets your chosen animation speed (`grub_frame_speed`), and applies the theme. |
| `output/grub-animation-x86_64.efi` | The final standalone x86_64 UEFI GRUB image — this is the file you'd use if you later decide to deploy it. |

Nothing is written outside `output/` (and, temporarily, `theme/animation/` when you import frames). No files outside this repository are ever created or modified by these scripts.

---

## 12. After customizing: rebuild workflow

There is one workflow, used both the first time and every time after:

1. Put your new/updated frames into `theme/animation/` (via `install-animation.sh` or by copying them in directly — step 7).
2. Run `./build.sh`.
3. Check `output/grub-animation-x86_64.efi`.

You do not need to reconfigure or rebuild GRUB itself (steps 4–6) again unless you change GRUB versions or need to re-apply the patch.

---

## 13. Bootloader safety

**This project's scripts never modify your system's bootloader.** Specifically, `install-animation.sh`, `validate.sh`, and `build.sh`:

- only read and write files inside this repository (`theme/`, `output/`),
- only *read* (never write to) the separate GRUB source/build directory you point them at,
- never touch `/boot`, your EFI System Partition, or `/etc/default/grub`,
- never call `grub-install`, `update-grub`, or any other system bootloader command.

Running these scripts, on any machine, cannot by itself change how that machine boots.

---

## 14. Deploying the EFI image (separate, manual, and higher-risk)

Getting `output/grub-animation-x86_64.efi` onto real boot media — for example, placing it on an EFI System Partition, adding a boot entry for it, or writing it to a bootable USB drive — is a **separate, manual step that this project deliberately does not automate.**

Only do this once you understand your own system's EFI/GRUB setup, because a mistake at this stage (unlike anything this project's scripts do) can affect whether your machine boots. Before deploying to a primary system:

- test it somewhere you're prepared to lose (a spare machine, a secondary boot entry, a test USB drive),
- keep a recovery plan on hand (e.g. a Linux live USB) in case something goes wrong,
- understand how to reverse whatever deployment method you choose before you use it.

This README does not provide deployment instructions, since the correct steps depend entirely on your specific system's partitioning and existing bootloader configuration.

---

## Troubleshooting

### Building a1ive GRUB itself (steps 4–6)

| Message | Meaning | Fix |
|---|---|---|
| `Gnulib not yet bootstrapped; run ./bootstrap instead.` | You ran `./autogen.sh` before `./bootstrap` | Run `./bootstrap` first (step 6), then `./autogen.sh` |
| `autopoint: not found` (during `./bootstrap`) | The `autopoint` package isn't installed | Install it: `sudo apt install -y autopoint` (see step 2 — it's a separate package from `gettext` on Debian/Ubuntu) |
| `error: dangling pointer to 'tmp_' may be used [-Werror=dangling-pointer=]` (during `make`) | Your compiler (commonly GCC 12+) treats a warning in GRUB's old code as a fatal error | Re-run `configure` with `--disable-werror` added (already included in this README's documented command), then `make` again |

### From `validate.sh`

| Message | Meaning | Fix |
|---|---|---|
| `ERROR: Animation directory not found` | `theme/animation/` doesn't exist | Make sure you're running the script from inside the project, and that the folder wasn't deleted |
| `ERROR: No PNG frames found.` | `theme/animation/` is empty, or your frames have an uppercase `.PNG` extension (see step 8 — the check is case-sensitive) | Import or copy frames in first (step 7), and confirm filenames use a lowercase `.png` extension |
| `ERROR: Invalid frame filename: xyz.png` | A frame isn't named as a plain integer | Rename to `1.png`, `2.png`, ... or re-run `install-animation.sh`, which does this for you |
| `ERROR: File is not a valid PNG` | A file has a `.png` extension but isn't actually PNG data | Re-export that frame as a genuine PNG |
| `ERROR: Missing frame: N.png` | There's a gap in your numbering | Renumber so there are no skipped integers between `1.png` and your last frame |
| `ERROR: Could not determine dimensions of 1.png` | `1.png` is unreadable or corrupted | Re-export `1.png` |
| `ERROR: Frame dimensions do not match` | One frame's resolution differs from `1.png` | Re-export all frames at identical width/height |

### From `install-animation.sh`

| Message | Meaning | Fix |
|---|---|---|
| `Usage: ./install-animation.sh animation.zip` | No ZIP path was given | Pass the path to your ZIP file as an argument |
| `ERROR: ZIP file not found` | The given path doesn't exist | Check the path and try again |
| `ERROR: No PNG files found in the ZIP.` | The ZIP contains no `.png` files | Check that your ZIP actually contains PNG frames, not another format |
| `ERROR: Not a valid PNG file in the ZIP: <name>` | One of the source files isn't really a PNG | Fix or remove that file from your ZIP and re-import — the original filename is reported so you can find it. **Your existing animation is left untouched** when this happens. |
| `ERROR: Frame dimensions do not match: <name>` | One of the ZIP's frames is a different resolution than the first frame | Re-export that frame at the same dimensions as the rest and re-import. **Your existing animation is left untouched** when this happens — this check now runs before anything is replaced. |

### From `build.sh`

| Message | Meaning | Fix |
|---|---|---|
| `ERROR: No animation frames found in: ...` | No frames to build with | Complete step 7 before building |
| `ERROR: GRUB build tools were not found.` | `grub-mkstandalone` doesn't exist at the expected path | Finish steps 4–6 (get, patch, and compile GRUB), or pass the correct path: `./build.sh /path/to/grub` |
| `ERROR: fullscreen-animation.patch does not appear to be applied` | GRUB was built without the patch from step 5 | Apply the patch (step 5) and rebuild GRUB (step 6), then re-run `./build.sh`. If you're certain the patch is applied but laid out differently, you can override with `ALLOW_UNPATCHED_GRUB=1 ./build.sh` |
| `ERROR: --fps must be a whole number between 1 and 60` | The value passed to `--fps` isn't a valid number in range | Use a plain integer between 1 and 60, e.g. `./build.sh --fps 24` |
| `NOTE: Could not find ... to verify the patch.` | The script couldn't locate the expected GRUB source file to check | Not an error — just confirm yourself that you applied the patch before compiling GRUB |

---

## Credits / Acknowledgements

- **[a1ive/grub](https://github.com/a1ive/grub)** — this project builds on the GRUB animation framework from this fork. The GRUB-derived source code referenced and patched by this project (`grub-core/gfxmenu/...`) is licensed under the GNU General Public License, version 3 (GPLv3); see `LICENSE` and `NOTICE` in this repository.
- **`fullscreen-animation.patch`** — an original two-file patch included in this repository, modifying `grub-core/gfxmenu/animation/engine_core.c` and `grub-core/gfxmenu/gui_canvas.c` from the a1ive/grub source above so the animation plays full-screen without being interrupted by menu selection changes.
- **OpenAI / ChatGPT** — assisted with project planning, debugging, documentation and workflow design, and general development guidance during this project's creation.
- **Claude (Anthropic)** — assisted with reviewing, improving, and editing this repository's scripts and documentation, including the safety checks in `build.sh`/`install-animation.sh`/`validate.sh` and this README.
- The generated theme configuration (`theme.txt`, produced by `build.sh`) references two fonts by name — "Funnel Sans Regular" and "Teko Regular" — for on-screen labels and menu text. These font files are **not bundled** in this repository; they must be available to your GRUB build separately (e.g. via GRUB's own font tooling) for those labels to render with the intended typeface.

No other third-party code, assets, or resources are bundled in or required by this repository beyond what's listed above.
