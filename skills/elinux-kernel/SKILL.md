---
name: elinux-kernel
description: Write, port, review or debug Linux kernel code for embedded boards - platform/I2C/SPI/V4L2 drivers, camera sensor (subdev) drivers, device tree, DT overlays, Kconfig/Makefile integration, built-in or module builds - on Raspberry Pi, BeagleBone Black and Renesas boards. Use when the task changes kernel space or the device tree, or asks how a kernel subsystem API works at a given kernel version. Do NOT use for userspace apps or libgpiod/i2c-dev code (use elinux-userspace), Yocto recipes that package kernel changes (use elinux-yocto), Buildroot kernel packages (use elinux-buildroot), cross toolchains (use elinux-buildsys-generic), or test plans and oops analysis (use elinux-testing). Run elinux-core first if the board or kernel is not confirmed.
---

# elinux-kernel

Kernel-space work: drivers, device tree, overlays, kernel config. Assumes the
target profile from `elinux-core` (board, SoC, kernel branch, userland, build
system). If the profile is missing, stop and run `elinux-core`.

## Applicability check (do this before writing any code)

1. **Does the thing already exist?** Search the *target's* kernel tree for an
   existing driver, binding and overlay (`grep -rn <compatible-or-name>
   drivers/ arch/*/boot/dts/ Documentation/devicetree/bindings`). If it exists,
   tell the user and ask: reuse it, or is writing a new one a learning
   exercise? A new driver for a supported sensor must use a **different
   name, Kconfig symbol and compatible**, never silently duplicate.
2. **Which kernel exactly?** Branch + version from the profile. All API names
   in `references/` carry the version they were checked against. If the
   user's kernel differs, re-verify the signatures in *their* headers before
   trusting a template.
3. **Built-in, module or out-of-tree?** Built-in (`=y`) drivers also need
   their Kconfig dependencies built-in: `=y` is silently demoted to `=m`
   when a dependency is `=m` (`references/fundamentals/kbuild-kconfig.md`).
4. **Hardware facts available?** I2C bus and address, supplies, reset/power
   GPIOs, clock rate, CSI lane count. If not from schematic/DT/datasheet,
   write `TODO(board)` / `TODO(datasheet)`; never fill from memory.
5. **Can the board recover?** Know the rollback path for a bad kernel/DT
   (`elinux-core/references/safety-checklist.md`).

## Workflow

1. Pick the subsystem chapter via `references/00-index.md`.
2. Read the chapter's *API and kernel versions* and *Common pitfalls*
   sections, then write code from the template, not from memory.
3. Write the DT/overlay in the same change as the driver; they are one
   deliverable. Lint with `scripts/lint_dts.sh`.
4. Wire the build: Kconfig + Makefile for built-in/module
   (`scripts/scaffold_sensor_driver.sh` does this for sensor drivers), or
   Kbuild for out-of-tree.
5. Compile against the *target's* headers with warnings on (`W=1`) and run
   `scripts/run_checkpatch.sh` style checks where applicable.
6. State what is verified (compiled, dtc-clean, overlay applied to the base
   DTB) and what needs the board.

## Where things are

| Need | File |
|---|---|
| Choose the right subsystem | `references/00-index.md` |
| Camera sensor driver (V4L2 subdev) | `references/subsystems/v4l2-subdev-sensor.md` |
| Media graph, `media-ctl` | `references/subsystems/media-controller.md` |
| I2C client driver rules | `references/subsystems/i2c.md` |
| Clocks and regulators | `references/subsystems/clk-regulator.md` |
| GPIO descriptors and pinctrl | `references/subsystems/gpio-pinctrl.md` |
| Device tree basics for drivers | `references/device-model/device-tree.md` |
| Overlays (Raspberry Pi specifics) | `references/device-model/overlays.md` |
| Kconfig/Makefile/built-in pitfalls | `references/fundamentals/kbuild-kconfig.md` |
| Pointers into `Documentation/` | `references/sources.md` |

| Template / script | Purpose |
|---|---|
| `templates/v4l2_sensor_driver.c` | CSI-2 raw sensor subdev driver skeleton (rpi-6.6.y) |
| `templates/overlay.dts` | Raspberry Pi camera overlay skeleton |
| `templates/Kconfig.snippet` | Kconfig entry for a sensor driver |
| `scripts/scaffold_sensor_driver.sh` | Instantiate template, wire into a kernel tree |
| `scripts/lint_dts.sh` | `dtc` lint, optional overlay-on-base check |

## Rules

- Prefer managed resources (`devm_*`) and `dev_err_probe()`; unwind in reverse
  order on every error path.
- No sleeping in atomic context; no blocking calls under spinlocks.
- Never trust register values you did not read from the datasheet.
- Keep driver, binding, overlay and Kconfig consistent: compatible string,
  supply names and clock names must match across all four.
- Do not paste mainline or vendor source into the answer; cite the file
  path and version in `references/sources.md` instead.
