# embedded-linux-skills

Claude skills for embedded Linux development (kernel + userspace +
Yocto/Buildroot/Makefile) on Raspberry Pi Zero/3/4/5, BeagleBone Black and
Renesas RZ/G2L and R-Car.

> Status: **vertical slice #1 is written**, the rest of the tree is stubs.
> Slice: *"write a V4L2 sensor driver for a camera on a Raspberry Pi Zero 2 W,
> built into the kernel, packaged with Yocto"*. Content is in English.

## Skills

| Skill | Purpose | State |
|---|---|---|
| `elinux-core` | router, target profile, board notes, safety | slice written (Pi Zero, camera stack) |
| `elinux-kernel` | drivers, device tree, overlays, Kconfig | slice written (V4L2 sensor, I2C, clk/regulator, GPIO, DT, overlays, Kbuild) |
| `elinux-buildsys-generic` | cross-compile, CMake/Make, sysroot, `-march` | written |
| `elinux-testing` | on-target tools, kernel testing, log analysis | slice written |
| `elinux-yocto` | meta-raspberrypi kernel patch/overlay packaging | slice written (parse-checked, not built) |
| `elinux-userspace` | system programming and hardware access | stub |
| `elinux-buildroot` | Buildroot packages and external trees | stub |

Each skill has a `SKILL.md` (under 500 lines, with "Use when" and "Do NOT use"
in the description) and `references/` chapters loaded on demand. Chapters
marked `Status: stub` are placeholders: they say so and must not be
improvised. Chapters follow the 8-section frame in `docs/CONTRIBUTING.md`
and record the kernel / Yocto / Buildroot versions they were checked against.

## Principles

- **No hardware facts from memory.** GPIOs, I2C bus/address, CSI lanes,
  clocks: from the schematic, datasheet or live DT. Code carries
  `TODO(board)` / `TODO(datasheet)`.
- **Version-pinned.** Every chapter has a `Verified:` line.
- **One source, three adapters.** CMake core; Yocto recipes and Buildroot
  packages only call into it.
- **No copyrighted text.** Concise original writing plus pointers to
  `Documentation/` paths and book chapters.

## Verified versions (slice #1)

- Kernel: Raspberry Pi `rpi-6.6.y` (6.6.78; Yocto pin 6.6.63).
- Yocto: scarthgap, meta-raspberrypi `raspberrypi0-2w-64` (parsed with
  `bitbake -p`, **not built or booted**).
- Buildroot: not covered yet.

## Validate

```sh
python3 tools/validate_skills.py \
    --kdir /path/to/prepared/rpi-linux \
    --base-dtb /path/to/bcm2710-rpi-zero-2-w.dtb     # dtc -@ build of the base DT
```
Without `--kdir` / `--base-dtb` the driver compile and overlay-apply checks
are reported as SKIP (not verified). See the header of
`tools/validate_skills.py`. Prepare a kernel tree with
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig modules_prepare`.

## Evals

`tests/evals/*.json`: prompts with `must` / `must_not` expectations for the
slice. They are graded by a human or a grader model; there is no automatic
runner yet.

## Layout

```
skills/<skill>/{SKILL.md,references/,templates/,scripts/}
tools/validate_skills.py      checks frontmatter, length, links, templates
tools/build_skills.py         packaging (stub)
tests/evals/                  prompts + expectations
docs/                         CONTRIBUTING.md, design-notes.md
shared/snippets/              shared sources copied into skills (stub)
```
