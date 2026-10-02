# Subsystem index

Status: complete (only entries marked **written** have content)
Verified: kernel=rpi-6.6.y@6.6.78; yocto=scarthgap (meta-raspberrypi); buildroot=n/a

## 1. When to use / not to use

Use to choose which chapter to read for a kernel task. Not a tutorial: each
row points to the chapter that is. Chapters still `Status: stub` must be
reported as missing, not improvised.

## 2. Conceptual model

Pick by **what the hardware is**, then by **what the kernel exposes to
userspace**:

| Hardware / goal | Subsystem | Chapter |
|---|---|---|
| CSI-2 camera sensor | V4L2 subdev + media controller | `subsystems/v4l2-subdev-sensor.md` (**written**), `subsystems/media-controller.md` (**written**) |
| Device on an I2C bus | I2C client driver | `subsystems/i2c.md` (**written**) |
| Clock / regulator consumer | clk, regulator frameworks | `subsystems/clk-regulator.md` (**written**) |
| Reset / enable / interrupt line | gpiod, pinctrl | `subsystems/gpio-pinctrl.md` (**written**) |
| Describe hardware | device tree | `device-model/device-tree.md` (**written**) |
| Add hardware at boot without rebuilding DTB | overlays | `device-model/overlays.md` (**written**) |
| Build integration, `=y` vs `=m` | Kbuild/Kconfig | `fundamentals/kbuild-kconfig.md` (**written**) |
| SPI device | SPI | `subsystems/spi.md` (stub) |
| Sensor/ADC on IIO | IIO | `subsystems/iio.md` (stub) |
| Anything else | see directory listing | stubs |

## 3. API and kernel versions

Every chapter has its own table; the index only fixes the branch of record:
`rpi-6.6.y` (6.6.78 when verified). Other kernels: re-verify signatures.

## 4. Device Tree binding

See `device-model/device-tree.md`; per-subsystem bindings are in each chapter.

## 5. Minimal example

"Write a V4L2 driver for a CSI camera on Raspberry Pi Zero 2 W, built into
the kernel":

1. `elinux-core` profile (board, 64-bit, rpi-6.6.y, Yocto).
2. Applicability check in `SKILL.md` (does a driver already exist? yes for
   OV5647: pick a new name).
3. `v4l2-subdev-sensor.md` -> template -> scaffold script.
4. `i2c.md`, `clk-regulator.md`, `gpio-pinctrl.md` for the resources.
5. `overlays.md` + `device-tree.md` -> overlay; `lint_dts.sh`.
6. `kbuild-kconfig.md` -> built-in config; `elinux-yocto` to package.
7. `elinux-testing` for on-target verification.

## 6. Common pitfalls

- Jumping to code before the applicability check.
- Reading a chapter for the wrong kernel version.
- Treating stub chapters as written.

## 7. How to test

`tools/validate_skills.py` checks that every chapter listed here exists and
that written chapters have all eight sections and a `Verified:` line.

## 8. References

- `references/sources.md` (pointers into `Documentation/`).
