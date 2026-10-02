# Media controller for sensor pipelines

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use when a sensor subdev feeds a receiver that exposes the pipeline as media
entities (Unicam with `brcm,media-controller`), and when you must configure
or debug formats between entities. Not needed for single-node webcam-style
devices where `/dev/videoN` is configured with `VIDIOC_S_FMT` alone.

## 2. Conceptual model

- **Entity**: a block (sensor, CSI receiver, video node). **Pad**: a
  connection point (source/sink). **Link**: pad-to-pad connection, can be
  enabled/disabled/immutable. The graph is read-only data to userspace
  except link state and subdev formats.
- A sensor registers one entity (function `MEDIA_ENT_F_CAM_SENSOR`) with one
  source pad (`media_entity_pads_init()`), flagged `V4L2_SUBDEV_FL_HAS_DEVNODE`
  so userspace gets `/dev/v4l-subdevN`.
- The receiver links the sensor pad to its sink pad when the async notifier
  completes (`v4l2_async_register_subdev_sensor()` makes the sensor the
  "endpoint" the receiver waits for).
- **Format propagation**: the sensor's source-pad format must equal what the
  receiver's sink pad is set to. Userspace sets the sensor format with
  `media-ctl --set-v4l2`, then the video node format.
- With subdev *active state*, the format set through `/dev/v4l-subdevN`
  persists in the driver's state and is what `s_stream` programs.

## 3. API and kernel versions

| API | Notes (rpi-6.6.y) |
|---|---|
| `media_entity_pads_init()`, `media_entity_cleanup()` | pair them in probe/remove |
| `entity.ops = {.link_validate = v4l2_subdev_link_validate}` | validates formats along links at stream-on |
| `v4l2_async_register_subdev_sensor()` | registers and parses fwnode properties for the notifier |
| `CONFIG_MEDIA_CONTROLLER`, `CONFIG_VIDEO_V4L2_SUBDEV_API` | required; `bcm2711_defconfig` has both `=y` |
| Unicam: `brcm,media-controller` | optional DT bool read in `bcm2835-unicam.c`; the stock `ov5647` overlay enables it |

## 4. Device Tree binding

The receiver (`csi1`) and the sensor each have a `port/endpoint` with
matching `remote-endpoint` phandles (bidirectional). `data-lanes` must agree
on both ends; `link-frequencies` is on the sensor endpoint. See
`references/device-model/overlays.md` for the overlay layout.

## 5. Minimal example

Inspect and configure (entity and device names come from your target; do not
copy them from this page):

```sh
media-ctl -d /dev/media0 -p                       # full graph with formats
media-ctl -d /dev/media0 -l                       # links only
media-ctl -d /dev/media0 --set-v4l2 '"<sensor-entity>":0[fmt:<MBUS_CODE>/<W>x<H>]'
v4l2-ctl -d /dev/v4l-subdev0 --list-subdev-mbus-codes
v4l2-ctl -d /dev/v4l-subdev0 --list-subdev-framesizes pad=0,code=<hex>
```

Find the right `/dev/mediaN`: `for m in /dev/media*; do media-ctl -d $m -p
| head -3; done`.

## 6. Common pitfalls

- Setting the video-node format before the sensor pad format: stream-on
  fails at link validation.
- Forgetting `V4L2_SUBDEV_FL_HAS_DEVNODE`: no `/dev/v4l-subdevN`, only the
  video node.
- Media device missing entirely: Unicam did not probe (overlay not
  applied, `csi1` not enabled, `VIDEO_BCM2835_UNICAM` not built).
- Graph present but sensor missing: the sensor probe failed or deferred
  (`dmesg`, `/sys/kernel/debug/devices_deferred`).
- `entity.function` or pad flags unset: userspace tools misclassify it.

## 7. How to test

`media-ctl -p` shows sensor + receiver linked and formats; then
`v4l2-ctl --stream-mmap --stream-count=5 --stream-to=/dev/null` and check
`dmesg` for link validation or CSI errors. Script:
`skills/elinux-testing/templates/smoke_test.sh`.

## 8. References

- `Documentation/driver-api/media/mc-core.rst`, `v4l2-subdev.rst`,
  `Documentation/userspace-api/media/mediactl/` (mainline).
- rpi-6.6.y: `drivers/media/platform/bcm2835/bcm2835-unicam.c`.
- `v4l-utils` documentation for `media-ctl` and `v4l2-ctl` (online).
