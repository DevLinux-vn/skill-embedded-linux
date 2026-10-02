# Raspberry Pi camera stack (Unicam + libcamera path) and where a sensor driver fits

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use when a task touches CSI-2 cameras on Raspberry Pi Zero/3/4: writing or
porting a sensor driver, writing an overlay, or debugging "no `/dev/video`",
"sensor not detected", "no frames". Do not use for USB cameras (UVC) or for
Pi 5 (different capture/ISP hardware: see `targets/rpi-5.md`), and do not use
it as a substitute for the sensor datasheet or camera-module schematic.

## 2. Conceptual model

```
 sensor (your driver)  --CSI-2-->  Unicam (CSI-2 receiver)  --> memory (CMA)
   I2C control path                    |
 (v4l2 subdev, /dev/v4l-subdevN)       +--> /dev/videoN (capture node)
                                              |
                                  bcm2835-isp (V4L2 mem2mem ISP, optional)
                                              |
                                      libcamera / rpicam-apps
```

- **Sensor driver** = V4L2 *subdev* on an I2C client. It exposes formats,
  crop, blanking, exposure/gain controls. It does *not* capture frames.
- **Unicam** (`brcm,bcm2835-unicam`, driver
  `drivers/media/platform/bcm2835/bcm2835-unicam.c`) is the CSI-2 receiver
  and video node. Node names `csi0`/`csi1` in the DT matter: the VideoCore
  firmware stops using the block when it finds them enabled, so the kernel
  driver can own it (verified from the binding text in the tree).
- **ISP**: `drivers/staging/vc04_services/bcm2835-isp` is a V4L2 mem2mem
  device used for Bayer-to-YUV conversion; libcamera's Raspberry Pi pipeline
  handler drives sensor + Unicam + ISP together. A raw sensor driver is
  useful with `v4l2-ctl` on its own, but ordinary camera apps additionally
  need a libcamera **camera sensor helper** and **tuning file** for that
  sensor (userspace, not kernel). Mention this; do not promise "works with
  rpicam-hello" from a kernel driver alone.
- **Media controller**: with `brcm,media-controller` set on `csi1` (the
  property read at `bcm2835-unicam.c`, optional), the graph is
  `sensor -> csi1 -> video node`, configured with `media-ctl`
  (`elinux-kernel/references/subsystems/media-controller.md`).
- **Legacy firmware camera stack** (`start_x`, `bcm2835-camera`/MMAL) is a
  different, mutually exclusive path; the Unicam Kconfig help says so.
  This repo targets the kernel/libcamera path.

## 3. API and kernel versions

| Item | Value (rpi-6.6.y) |
|---|---|
| Sensor API | V4L2 subdev with active state, `v4l2-cci` helpers present |
| Unicam | `VIDEO_BCM2835_UNICAM` (tristate, `depends on VIDEO_DEV`) |
| Reference sensor driver in tree | `drivers/media/i2c/ov5647.c`, `imx219.c` |
| Reference overlays | `overlays/ov5647-overlay.dts`, `imx219-overlay.dts` |

`bcm2711_defconfig` (used by `raspberrypi0-2w-64`) has `VIDEO_DEV=m`, so a
sensor driver set to `=y` is demoted to `=m` unless `VIDEO_DEV` (and
`V4L2_FWNODE`, `V4L2_CCI_I2C`) are also `=y`. Verified by `olddefconfig` on
rpi-6.6.y; see `elinux-kernel/references/fundamentals/kbuild-kconfig.md`.

## 4. Device Tree binding

Sensor binding: `Documentation/devicetree/bindings/media/video-interfaces.yaml`
plus the sensor's own YAML (for OV5647: `media/i2c/ovti,ov5647.yaml`).
Receiver binding: `Documentation/devicetree/bindings/media/bcm2835-unicam.txt`
(rpi tree). Required in the endpoint: `remote-endpoint`, `data-lanes`
(in order starting at 1, no reordering). Overlay structure:
`elinux-kernel/references/device-model/overlays.md` and
`elinux-kernel/templates/overlay.dts`.

## 5. Minimal example

Bring-up order that localises faults:

1. Power/clock/I2C: does the sensor answer on the I2C bus the overlay
   selected? (`i2cdetect -l`, bus from `dmesg`/DT; address from datasheet.)
2. Driver probe: `dmesg | grep -i <sensor>`; chip-ID read passes.
3. Media graph: `media-ctl -p` shows sensor and `csi1` linked.
4. Format: `media-ctl --set-v4l2 ...` then `v4l2-ctl --stream-mmap`.
5. Only then: libcamera tuning and apps.

## 6. Common pitfalls

- Overlay not loaded (not in `config.txt`, or `.dtbo` missing from the
  image): driver never probes. Check `/proc/device-tree/soc/...` for the
  node before debugging the driver.
- Wrong I2C bus/address, or XCLK frequency not matching the driver's
  expectation: probe fails at chip-ID read.
- `data-lanes` in the overlay larger than lanes wired on the connector
  (and `brcm,num-data-lanes` in the base DT): link fails after probe.
- Driver asked to hold the sensor in a mode (blanking, link frequency) that
  disagrees with the `link-frequencies` in DT: Unicam rejects or frames are
  corrupt.
- Expecting `rpicam-*` apps to work without a libcamera sensor helper and
  tuning file.

## 7. How to test

`elinux-testing/references/on-target-tools.md` (media-ctl, v4l2-ctl, dmesg)
and `elinux-testing/templates/smoke_test.sh`.

## 8. References

- rpi-6.6.y: `drivers/media/platform/bcm2835/bcm2835-unicam.c`,
  `drivers/media/platform/bcm2835/Kconfig`,
  `Documentation/devicetree/bindings/media/bcm2835-unicam.txt`,
  `arch/arm/boot/dts/overlays/README` (section `ov5647`).
- Mainline: `Documentation/driver-api/media/camera-sensor.rst`,
  `Documentation/userspace-api/media/v4l/dev-subdev.rst`.
- libcamera Raspberry Pi pipeline handler documentation (online).
