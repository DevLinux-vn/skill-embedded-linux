---
name: elinux-core
description: Entry point and router for embedded Linux work (kernel drivers, userspace apps, Yocto/Buildroot/Makefile builds) on Raspberry Pi Zero/3/4/5, BeagleBone Black and Renesas RZ/G2L and R-Car. Use when starting any embedded Linux task, when the target board, SoC, kernel version or build system is unknown or unconfirmed, or when deciding which elinux-* skill applies. Do NOT use for writing the driver code itself (use elinux-kernel), application code (use elinux-userspace), Yocto recipes (use elinux-yocto), Buildroot packages (use elinux-buildroot), cross-compile toolchains and CMake/Make (use elinux-buildsys-generic) or test strategy and log analysis (use elinux-testing).
---

# elinux-core: router and target profile

Run this skill first. It builds a **target profile**, runs a safety pass, then
hands the task to the specialist skill. Never skip the profile: most embedded
Linux failures come from a wrong assumption about the board, kernel tree or
build system, not from the code.

## Workflow

1. **Detect the build system** if a source tree is available:
   `skills/elinux-core/scripts/detect_build_system.sh <dir>` prints one of
   `yocto`, `buildroot`, `kernel-tree`, `cmake`, `make`, `unknown` plus the
   evidence. Treat the result as a hint and confirm it with the user.
2. **Fill the target profile** using `references/target-profile.md`. Ask only
   for what is missing; do not guess board revision, SoC, kernel branch,
   userland bitness or OS/build system.
3. **Load the board file** from `references/targets/` for the confirmed board
   (see routing table). Board files are pointers and checklists, not pin maps.
4. **Run the safety pass** (`references/safety-checklist.md`): is this
   change able to hang the board, corrupt storage, or brick the boot path?
   Decide the rollback path *before* writing code.
5. **Route** to the specialist skill and carry the profile along.
6. **Close with verification**: say exactly what was built, what was only
   statically checked, and what still needs the real board.

## Routing table

| Task | Skill | Typical first reference |
|---|---|---|
| Kernel driver, device tree, overlay, kernel config | `elinux-kernel` | `elinux-kernel/references/00-index.md` |
| Camera sensor / V4L2 / media-controller driver | `elinux-kernel` | `elinux-kernel/references/subsystems/v4l2-subdev-sensor.md` |
| Application, daemon, libgpiod, systemd service | `elinux-userspace` | `elinux-userspace/references/00-index.md` |
| Yocto layer, recipe, bbappend, image | `elinux-yocto` | `elinux-yocto/references/kernel-recipe-and-config.md` |
| Buildroot package, defconfig, external tree | `elinux-buildroot` | `elinux-buildroot/references/package-anatomy.md` |
| Toolchain file, `-march`, sysroot, Makefile/CMake | `elinux-buildsys-generic` | `elinux-buildsys-generic/references/cross-compile.md` |
| Test plan, on-target tools, kernel/oops log reading | `elinux-testing` | `elinux-testing/references/on-target-tools.md` |

A request often spans skills (e.g. a sensor driver = kernel + yocto + testing).
Route in dependency order and say which skill each step uses.

## Board files

| Board | File |
|---|---|
| Raspberry Pi Zero / Zero W / Zero 2 W | `references/targets/rpi-zero.md` |
| Raspberry Pi 3 / 4 | `references/targets/rpi-3-4.md` |
| Raspberry Pi 5 | `references/targets/rpi-5.md` |
| BeagleBone Black | `references/targets/beaglebone-black.md` |
| Renesas RZ/G2L | `references/targets/renesas-rzg2l.md` |
| Renesas R-Car | `references/targets/renesas-rcar.md` |

Files marked `Status: stub` are not written yet: say so, ask the user for the
board documentation, and do not improvise from memory.

## Hard rules (apply to every elinux-* skill)

- **No hardware facts from memory.** GPIO numbers, I2C bus numbers and
  addresses, CSI lane counts, clock rates, regulator wiring, pinmux and
  memory maps come from the schematic, the board's DT/overlay, or the
  datasheet. When writing code, leave `TODO(board)` / `TODO(datasheet)` and
  give the command that obtains the value (e.g. `dtc -I fs -O dts
  /proc/device-tree`, `gpioinfo`, `i2cdetect -l`, `media-ctl -p`).
- **Version-pin every claim.** Kernel APIs move. State the kernel branch the
  advice was checked against and flag anything unverified.
- **One source, three adapters.** Application logic lives in a CMake core;
  Yocto recipes and Buildroot packages only call into it
  (`elinux-buildsys-generic/references/one-source-three-adapters.md`).
- **Do not copy book or mainline text.** Summarise, then point to the
  `Documentation/` path or book chapter.
- **Report honestly.** Separate "compiled", "linted", "booted on target"
  and "not tested".

## Applicability check (always before generating code)

Answer these from the profile; if any is unknown, ask.

1. Which exact board and SoC? (Zero vs Zero 2 W differ in CPU architecture.)
2. Which kernel tree and version is actually running or will be built?
3. Which userland bitness (32 vs 64-bit) and which OS/build system?
4. Does a driver/overlay for this hardware already exist in that tree?
   If yes, say so before writing a new one (learning exercise vs. real need).
5. Is the code built into the kernel, a module, or userspace?
