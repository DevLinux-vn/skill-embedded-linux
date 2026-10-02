# Device tree overlays (Raspberry Pi tree)

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1; template overlay applied with fdtoverlay to a bcm2710-rpi-zero-2-w.dtb built with DTC_FLAGS=-@ and built as a .dtbo by the tree's own Makefile); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use to add or change hardware description without rebuilding the board DTB:
camera sensors, HATs, buses. Not for hardware that is permanently part of
the board (edit the board DTS), and not for boards whose boot flow does not
apply overlays (check the boot path in the target profile).

## 2. Conceptual model

- An overlay is a DTB fragment set (`/plugin/;`) with `fragment@N { target =
  <&label>; __overlay__ { ... }; }`. The loader merges it into the base DT
  before the kernel sees it.
- **Raspberry Pi**: the VideoCore firmware applies overlays named by
  `dtoverlay=<name>[,param=val]` in `config.txt`, from `overlays/<name>.dtbo`
  in the boot partition. It also understands `__overrides__` (runtime
  parameters) - an RPi extension that the mainline `fdtoverlay` ignores.
- Overlay targets are **labels of the base DT** (`csi1`, `i2c0mux`,
  `i2c_csi_dsi`, `cam1_reg`, `cam1_clk` are defined in
  `bcm270x.dtsi`). They must exist in the base DTB `__symbols__`.
- Overlays for the Raspberry Pi tree are built *by the kernel build*:
  list `<name>.dtbo` in `arch/arm/boot/dts/overlays/Makefile`, source file
  `<name>-overlay.dts`.
- For a sensor, the overlay normally has: sensor node on the camera I2C
  bus, enabling of the CSI receiver with the matching endpoint, enabling of
  the I2C mux, clock rate and regulator delay.

## 3. API and kernel versions

| Item | rpi-6.6.y |
|---|---|
| Overlay build | `overlays/Makefile` `dtbo-$(...) += <name>.dtbo` list; file `<name>-overlay.dts` |
| Loader | firmware via `config.txt` `dtoverlay=` (not the kernel's `of_overlay_*` at runtime) |
| Stock sensor overlays | `imx219`, `ov5647`, ... (`overlays/README` documents parameters) |
| Compile | `dtc -@` (symbols) for both base and overlay |

## 4. Device Tree binding

The overlay carries the nodes whose bindings the driver defines
(`device-tree.md`). Keep `compatible`, supply and clock names identical to
the driver, and the overlay's `link-frequencies` / `data-lanes` identical to
the driver's checks.

## 5. Minimal example

`templates/overlay.dts` is the working skeleton (sensor + Unicam + mux +
clock + regulator delay). Build and check it:

```sh
# standalone syntax + symbol resolution
skills/elinux-kernel/scripts/lint_dts.sh templates/overlay.dts \
        --base bcm2710-rpi-zero-2-w.dtb
# in the kernel tree: add "<name>.dtbo \" to overlays/Makefile, then
make ARCH=arm64 DTC_FLAGS=-@ overlays/<name>.dtbo
```
Enable on target (`/boot/firmware/config.txt`, path varies by image):
`dtoverlay=<name>`. Yocto: `elinux-yocto/references/devicetree-in-yocto.md`.

## 6. Common pitfalls

- **Label on the `__overlay__` node itself** (`csi: __overlay__ {`): the
  Raspberry Pi firmware accepts it, but `fdtoverlay` fails with
  `FDT_ERR_NOTFOUND`. The template avoids it so it can be tested; put labels
  on the nodes *inside* `__overlay__`.
- Overlay `.dtbo` missing from the image or from the boot partition (Yocto:
  not in `RPI_KERNEL_DEVICETREE_OVERLAYS`).
- Overlay compiled without `-@`, or base DTB without symbols: unresolved
  label.
- `dtoverlay=` line after a conflicting overlay, or two overlays claiming
  the same I2C address (the in-tree `ov5647` overlay and yours).
- Parameters (`rotation=`, `orientation=`) only work through
  `__overrides__`; they do nothing under plain `fdtoverlay`.
- Testing the overlay on a different board DT than the one that boots: the
  Zero W and Zero 2 W DTs wire the camera mux differently.
- Forgetting that firmware, not the kernel, applied the overlay: debug
  with `/proc/device-tree`, `vcdbg log msg` and `dtoverlay -h` on the
  target, not `dmesg` alone.

## 7. How to test

1. Host: `lint_dts.sh` with `--base` (compiles, applies, shows the node).
2. Target, after boot: `ls /proc/device-tree/soc/i2c0mux/i2c@1/`, `dmesg |
   grep -i <name>`, `media-ctl -p`.
3. Negative test: remove the overlay line and confirm the driver is not
   probed (no stale state).

## 8. References

- rpi-6.6.y: `arch/arm/boot/dts/overlays/README`, `ov5647-overlay.dts`,
  `overlays/Makefile`; `Documentation/devicetree/overlay-notes.rst`.
- Raspberry Pi documentation: "Device Trees, overlays and parameters"
  (online).
