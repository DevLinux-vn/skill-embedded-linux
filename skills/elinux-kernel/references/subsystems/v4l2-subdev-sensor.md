# V4L2 camera sensor driver (subdev)

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1; template compiled with W=1 against its headers, arm64 bcm2711_defconfig); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use for a MIPI CSI-2 raw Bayer sensor controlled over I2C and receiving frames
through a separate CSI receiver (Unicam on Raspberry Pi). Do not use for:
USB/UVC cameras, sensors that bundle their own ISP and output YUV over a
parallel bus (different mbus formats and bus type), or sensor+bridge chips
that register a video node themselves. Do not use as a datasheet: all
register values stay `TODO(datasheet)` until taken from the sensor docs.

## 2. Conceptual model

A sensor driver is an **I2C client that registers a V4L2 subdevice with one
source pad**. It never moves pixels. Four responsibilities:

1. **Power sequencing**: supplies -> clock -> reset/power-down -> wait. One
   function pair (`power_on`/`power_off`) used by runtime PM.
2. **Formats and geometry**: media bus code (Bayer order, bit depth), frame
   size per *mode*, crop rectangle, blanking. State lives in the subdev
   *active state*, not in driver globals.
3. **Controls**: pixel rate, link frequency (read-only), h/v blank,
   exposure, gain, plus `rotation`/`orientation` read from DT. Controls
   whose ranges depend on the mode are updated in `set_fmt`.
4. **Streaming**: program the mode's register list, replay controls, then
   set the stream-on register; reverse on stop.

Lifecycle: `probe` -> parse endpoint -> get clk/regulators/gpio -> power on
-> read chip ID -> init controls -> init media entity -> init subdev state ->
enable runtime PM -> `v4l2_async_register_subdev_sensor()` (the receiver
binds to it asynchronously) -> allow autosuspend.

Locking: one lock for subdev state *and* control handler
(`sd.state_lock = ctrls.lock`), so `s_ctrl`, `set_fmt` and `s_stream` cannot
race. `s_stream` holds it while calling `__v4l2_ctrl_handler_setup()`.

## 3. API and kernel versions

Checked against rpi-6.6.y (headers in `include/media/`):

| API | 6.6 form (used by template) |
|---|---|
| I2C probe | `int probe(struct i2c_client *)`, `void remove(struct i2c_client *)` |
| Register access | `v4l2-cci.h`: `CCI_REG8/16(...)`, `devm_cci_regmap_init_i2c()`, `cci_read/write()`, `cci_multi_reg_write()`; needs `select V4L2_CCI_I2C` |
| Subdev state | `v4l2_subdev_init_finalize()` / `v4l2_subdev_cleanup()`; `v4l2_subdev_lock_and_get_active_state()` |
| Pad state accessors | `v4l2_subdev_get_pad_format()`, `v4l2_subdev_get_pad_crop()`; `get_fmt = v4l2_subdev_get_fmt` |
| Pad init | `.init_cfg` pad op |
| Sensor registration | `v4l2_async_register_subdev_sensor()` |
| Runtime PM | `DEFINE_RUNTIME_DEV_PM_OPS`, `pm_ptr()` |
| Endpoint parsing | `v4l2_fwnode_endpoint_alloc_parse()` with `V4L2_MBUS_CSI2_DPHY` |

Newer kernels: names changed (for example the pad-state accessors and
`init_cfg` were reworked in later mainline releases). **[UNVERIFIED here]**
- if the target kernel is not 6.6, grep the target's `v4l2-subdev.h` for
`init_state`, `v4l2_subdev_state_get_format`, `v4l2_subdev_state_get_crop`
before reusing the template.

Older kernels (before `v4l2-cci.h` and active state, roughly pre-6.3/6.6):
the template does not apply as is. Check `include/media/v4l2-cci.h` exists.

## 4. Device Tree binding

Sensor node (child of the I2C bus the camera connector uses):

- `compatible`, `reg` (I2C address): `TODO(datasheet)` / `TODO(board)`.
- `clocks` (XCLK), supply properties named exactly as the driver's
  `supply` strings (`avdd`, `dovdd`, `dvdd` in the template: rename to the
  sensor's real supplies and keep the binding in sync).
- optional `reset-gpios` / power-down GPIO.
- `rotation`, `orientation` (parsed by `v4l2_fwnode_device_parse()`).
- `port/endpoint`: `remote-endpoint`, `data-lanes`, `clock-noncontinuous`
  (if the sensor uses a non-continuous clock), `link-frequencies`.

Binding schema guidance: `Documentation/devicetree/bindings/media/video-interfaces.yaml`;
sibling example `media/i2c/ovti,ov5647.yaml`. The Raspberry Pi tree keeps
Unicam's binding in `bcm2835-unicam.txt`.

## 5. Minimal example

Use the template, do not hand-write from memory:

```sh
skills/elinux-kernel/scripts/scaffold_sensor_driver.sh \
    --name mycam --vendor acme --kernel-dir /path/to/rpi-linux
# -> drivers/media/i2c/mycam.c, Kconfig + Makefile entries,
#    overlays/mycam-overlay.dts, mycam.config
```

Fill in, in this order: `TODO(datasheet)` registers and chip ID (until
`MYSENSOR_CHIP_ID` matches, probe returns -ENODEV by design), mode table,
power-up delays, supplies, lane count, link frequency, pixel rate; then the
overlay's `TODO(board)` entries.

### Cross-check list for an OV5647 driver written from scratch

When the sensor is OV5647, take register values and timings from its
datasheet / your vendor register tables. For *cross-checking* the
integration (not copying), the reference driver and overlay in rpi-6.6.y
(verified by reading them) use: 25 MHz XCLK (`clock-frequency` in the
overlay; probe rejects other rates), I2C address from `ov5647.dtsi`,
three supplies, optional `pwdn` GPIO, 2 data lanes, `clock-noncontinuous`,
one `link-frequencies` entry, and `brcm,media-controller` on `csi1`. If your
driver or overlay disagrees with any of these, find out which side is
wrong before debugging further.

New-name rule: the in-tree driver already claims `ovti,ov5647` and
`CONFIG_VIDEO_OV5647`. A from-scratch driver in the same tree needs a
distinct compatible, symbol and module name, and the stock overlay must not
be loaded at the same time (two drivers, one I2C address).

## 6. Common pitfalls

- **Probe order**: clock rate read before the clock is usable; regulators
  fetched but never enabled; reset released before supplies are stable.
- **Missing `-EPROBE_DEFER` propagation**: use `dev_err_probe()` so a late
  regulator/clock provider defers instead of failing.
- **Unconditional register writes in `s_ctrl`** while powered down: guard
  with `pm_runtime_get_if_in_use()`; replay controls on stream-on.
- **Blanking vs exposure**: exposure maximum is `frame_length - margin`;
  update its range whenever VBLANK changes.
- **Format/crop in state**: updating driver-global copies instead of the
  subdev state breaks TRY formats.
- **Pixel rate / link frequency mismatch with DT**: receiver rejects the
  stream. Derive pixel rate from the datasheet's PLL settings.
- **Bayer order after flips**: a hflip/vflip control changes the Bayer
  pattern; model it in the mbus code or omit the controls.
- **`=y` build demoted to `=m`** (see `references/fundamentals/kbuild-kconfig.md`).
- **Probe `-ENODEV` on a real chip** after filling the template: chip-ID
  registers/width wrong, I2C address wrong, sensor not powered or XCLK absent.

## 7. How to test

1. Compile: scaffold into the target's tree, `make drivers/media/i2c/<name>.o W=1`
   (or let `tools/validate_skills.py` do the template check).
2. Overlay: `scripts/lint_dts.sh` (dtc, and overlay applied to the base DTB).
3. On target: `dmesg`, then `media-ctl -p`, `v4l2-ctl -d /dev/v4l-subdev0 -l`,
   `v4l2-ctl --stream-mmap --stream-count=...` (`elinux-testing`).
4. Unload/reload (if module) and repeated stream start/stop to exercise
   runtime PM and error paths; kernel built with `KASAN`/`DEBUG_ATOMIC_SLEEP`
   on a test image if possible (`elinux-testing/references/kernel-testing.md`).

## 8. References

- Mainline docs: `Documentation/driver-api/media/camera-sensor.rst`,
  `v4l2-subdev.rst`, `v4l2-cci.rst`, `v4l2-controls.rst`, `v4l2-fwnode.rst`,
  `Documentation/userspace-api/media/v4l/dev-subdev.rst`.
- rpi-6.6.y reference drivers: `drivers/media/i2c/ov5647.c`, `imx219.c`
  (read for structure, do not paste).
- Sensor datasheet and register programming guide (from the vendor).
- Books: *Linux Device Drivers 3rd ed.* ch. 3 and 14 (driver and device model
  fundamentals; V4L2 itself is not covered); see `../sources.md`.
