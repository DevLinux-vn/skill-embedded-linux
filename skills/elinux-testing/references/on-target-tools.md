# On-target tools

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (flags reviewed against the subsystem docs; tools not executed on a board in this repo); yocto=scarthgap (package names to be confirmed per image); buildroot=n/a

## 1. When to use / not to use

Use to inspect and exercise hardware from a running target: buses, GPIO,
media pipelines, CAN. Not for host-side tests, and not a replacement for
reading the schematic: tools show what the kernel thinks, not how it is wired.

## 2. Conceptual model

Each tool reads a kernel interface; failures usually mean the interface is
missing (driver not bound), not that the tool is broken.

| Question | Tool | Kernel interface |
|---|---|---|
| Which I2C buses exist? | `i2cdetect -l` | `/dev/i2c-N`, sysfs |
| Does an address answer? | `i2cdetect -y -r <bus>` (see caution), `i2cget` | `i2c-dev` |
| Is my driver bound? | `ls /sys/bus/i2c/drivers/<name>/`, `dmesg` | sysfs |
| GPIO lines, names, owners | `gpioinfo`, `gpiomon`, `gpioget` (libgpiod) | `/dev/gpiochipN` |
| Media graph | `media-ctl -p`, `-l` | `/dev/mediaN` |
| Subdev formats/controls | `v4l2-ctl -d /dev/v4l-subdevN --all` | `/dev/v4l-subdevN` |
| Capture | `v4l2-ctl --stream-mmap`, `--stream-to` | `/dev/videoN` |
| Live DT | `dtc -I fs -O dts /proc/device-tree` | `/proc/device-tree` |
| Clocks / regulators | `/sys/kernel/debug/clk/clk_summary`, `.../regulator/regulator_summary` | debugfs |
| CAN | `candump`, `cansend`, `ip -details link show can0` | SocketCAN |
| Kernel log | `dmesg -w`, `journalctl -k` | ring buffer |

## 3. API and kernel versions

Tools come from `i2c-tools`, `libgpiod-tools`, `v4l-utils`, `can-utils`.
libgpiod v1 vs v2 tools differ in syntax (`gpioget` options changed); check
`gpioinfo --version` before copying commands. `/dev/mediaN`, `/dev/videoN`
and `/dev/v4l-subdevN` numbering is not stable across boots: discover it.
debugfs must be mounted (`mount -t debugfs none /sys/kernel/debug`).

## 4. Device Tree binding

Not applicable; tools inspect the result of the DT.

## 5. Minimal example

```sh
# discover, never assume numbers
for m in /dev/media*; do echo "== $m"; media-ctl -d "$m" -p | head -5; done
dmesg | grep -i -E 'i2c|csi|unicam|<sensor>|probe'
v4l2-ctl --list-devices
# stream a handful of frames to /dev/null as a first data-path test
v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=10 --stream-to=/dev/null
```

## 6. Common pitfalls

- `i2cdetect` without `-r` writes quick-write probes; on some chips this
  changes state. Prefer `-r` or an explicit register read from the datasheet.
- Probing a bus owned by the firmware/another driver while it is in use.
- Assuming `/dev/video0` is the camera: other video nodes exist (ISP, codecs).
- Missing package in a minimal image (Yocto/Buildroot): the tool is absent,
  not the hardware (add `v4l-utils`, `i2c-tools`, `libgpiod-tools`).
- Reading old dmesg: reboot or `dmesg -C` before the test to isolate the run.

## 7. How to test

These *are* the tests. Record the exact command and the raw output for each
claim. `templates/smoke_test.sh` strings the camera ones together.

## 8. References

- `Documentation/i2c/dev-interface.rst`, `Documentation/userspace-api/gpio/`,
  `Documentation/userspace-api/media/` (mainline).
- Manual pages: `media-ctl(1)`, `v4l2-ctl(1)`, `i2cdetect(8)`, `gpioinfo(1)`.
