# Target: Raspberry Pi Zero family (Zero, Zero W, Zero 2 W)

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use for any task on Raspberry Pi Zero, Zero W or Zero 2 W. Do not use for
Pi 3/4 (`rpi-3-4.md`) or Pi 5 (`rpi-5.md`, different I/O and camera
hardware), and do not use it as a pin map: it never lists GPIO, I2C or lane
facts. Those come from the schematic and the active DT.

## 2. Conceptual model

Three boards, two CPU architectures. Decide which one first.

| Board | SoC (from DT compatible, verify on target) | CPU | Userland options |
|---|---|---|---|
| Zero, Zero W | BCM2835 | ARMv6 (ARM1176) | 32-bit only (`armv6`, hard-float) |
| Zero 2 W | BCM2710A1 (DT: `bcm2710-rpi-zero-2-w`) | quad Cortex-A53 | 32-bit (armv7/`raspberrypi0-2w`) or 64-bit (aarch64/`raspberrypi0-2w-64`) |

Consequences you must carry into every other skill:

- **Toolchain/ABI follows userland bitness, not the CPU.** Zero 2 W with a
  64-bit image needs an aarch64 toolchain; with a 32-bit image an armv7
  toolchain; Zero/Zero W needs armv6 (`elinux-buildsys-generic`).
- **Kernel config and DT file differ per board.** In Yocto
  (meta-raspberrypi scarthgap, verified from the machine files):
  `raspberrypi0-2w-64` includes `raspberrypi3-64`, so
  `KBUILD_DEFCONFIG` is `bcm2711_defconfig` and `RPI_KERNEL_DEVICETREE` is
  `broadcom/bcm2710-rpi-zero-2.dtb`; `raspberrypi0-2w` is the 32-bit
  variant; `raspberrypi0`/`raspberrypi0-wifi` are the ARMv6 boards.
- **Memory is small** on all Zero variants (check `free -m`): kernel,
  CMA reservation and camera buffers compete. Do not copy CMA sizes from
  a Pi 4 guide.
- **Boot is by the VideoCore firmware**, not U-Boot, unless the build system
  adds U-Boot (`RPI_USE_U_BOOT` in meta-raspberrypi). The firmware reads
  `config.txt` and applies overlays (`dtoverlay=`) before the kernel starts.
- **Camera connector wiring differs between Zero W and Zero 2 W.** In the
  rpi-6.6.y tree the two board DTs include *different* I2C-mux DTSI files
  (`bcm283x-rpi-i2c0mux_0_28.dtsi` vs `bcm283x-rpi-i2c0mux_0_44.dtsi`) and
  set `cam1_reg` GPIO in the board file. Never reuse overlay values written
  for another board revision without reading that board's DT.

## 3. API and kernel versions

Kernel branch of record: Raspberry Pi `rpi-6.6.y`. Yocto scarthgap's
`linux-raspberrypi_6.6.bb` pinned `LINUX_VERSION = 6.6.63` when verified; the
branch head was 6.6.78. Both are 6.6.x, so one API surface; re-check
`SRCREV_machine` before trusting a specific patch level.

Branch/version drift is the main hazard: a newer rpi branch can change media
drivers (unicam, ISP) and overlay contents. Re-verify before adapting this
file to another branch.

## 4. Device Tree binding

Board DT entry points (rpi-6.6.y, `arch/arm/boot/dts/broadcom/`):

- `bcm2710-rpi-zero-2-w.dts` (Zero 2 W); `bcm2710-rpi-zero-2.dts` is a thin
  include of it.
- `bcm2708-rpi-zero-w.dts`, `bcm2708-rpi-zero.dts` (ARMv6 boards).
- Shared SoC layer: `bcm270x.dtsi` (defines the labels overlays rely on:
  `csi1`, `i2c0mux`, `i2c_csi_dsi`, `cam1_reg`, `cam1_clk`).
- Camera lane count for `csi1` on the Zero 2 W comes from
  `bcm283x-rpi-csi1-2lane.dtsi` (`brcm,num-data-lanes`).

Always read the **running** DT, not the source:
`dtc -I fs -O dts /proc/device-tree > /tmp/live.dts`.

## 5. Minimal example

Check what you are on, before anything else:

```sh
cat /proc/device-tree/model            # exact board
uname -m; getconf LONG_BIT             # userland bitness
free -m                                # memory budget
vcgencmd get_camera 2>/dev/null || true  # legacy firmware camera stack only
ls /boot/firmware/overlays | head      # overlays shipped by the image
```

## 6. Common pitfalls

- Treating Zero 2 W as ARMv6 (or Zero as 64-bit capable).
- Mixing a 32-bit userland with an aarch64-built module, or the reverse.
  The module must match the **kernel** (`uname -m`), userland apps match
  the **rootfs**.
- Enabling `csi1` while the legacy firmware camera stack is in use: the
  firmware only releases the Unicam block when the DT has the `csi0`/`csi1`
  nodes enabled (see `rpi-camera-stack.md`).
- Forgetting the overlay in the image: in meta-raspberrypi the default
  `RPI_KERNEL_DEVICETREE_OVERLAYS` list does not ship every sensor overlay
  (verified: it lists `imx219`, not `ov5647`). Append yours.
- Powering the board from a weak supply and blaming the driver for resets.

## 7. How to test

- `dmesg | grep -i -E 'unicam|csi|i2c|<sensor>'` after boot.
- `media-ctl -p`, `v4l2-ctl --list-devices` for the camera graph.
- See `elinux-testing/references/on-target-tools.md`.

## 8. References

- `arch/arm/boot/dts/overlays/README` (rpi-6.6.y).
- meta-raspberrypi (scarthgap): `conf/machine/raspberrypi0-2w-64.conf`,
  `conf/machine/raspberrypi0-2w.conf`, `conf/machine/raspberrypi0*.conf`,
  `recipes-kernel/linux/linux-raspberrypi.inc`.
- Raspberry Pi documentation: camera and `config.txt` sections (online,
  not mirrored here).
