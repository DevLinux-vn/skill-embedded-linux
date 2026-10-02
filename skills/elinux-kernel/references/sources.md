# Sources: pointers only (no mainline text is copied into this repo)

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (every path below was checked to exist in that tree); yocto=n/a; buildroot=n/a

## 1. When to use / not to use

Use to find the authoritative document for a kernel topic. Do not paste
from these into answers: summarise and cite the path and version.

## 2. Conceptual model

Mainline documentation is the source of truth for APIs; the Raspberry Pi
tree adds board DTs, overlays and drivers. Books give background only.

## 3. API and kernel versions

Paths below are relative to the kernel source root, rpi-6.6.y (6.6.78).
Refresh with `scripts/sync_docs.sh` (stub) when moving to another tag.

| Topic | Path |
|---|---|
| Camera sensor drivers | `Documentation/driver-api/media/camera-sensor.rst` |
| V4L2 subdev, controls, fwnode, CCI | `Documentation/driver-api/media/v4l2-subdev.rst`, `v4l2-controls.rst`, `v4l2-fwnode.rst`, `v4l2-cci.rst` |
| Media controller | `Documentation/driver-api/media/mc-core.rst`; `Documentation/userspace-api/media/mediactl/` |
| Subdev userspace API | `Documentation/userspace-api/media/v4l/dev-subdev.rst` |
| I2C | `Documentation/i2c/writing-clients.rst`, `Documentation/driver-api/i2c.rst` |
| Clock / regulator | `Documentation/driver-api/clk.rst`, `Documentation/power/regulator/consumer.rst` |
| GPIO / pinctrl | `Documentation/driver-api/gpio/consumer.rst`, `Documentation/driver-api/pin-control.rst` |
| Runtime PM | `Documentation/power/runtime_pm.rst` |
| Device tree | `Documentation/devicetree/usage-model.rst`, `overlay-notes.rst`, `bindings/writing-bindings.rst`, `bindings/writing-schema.rst` |
| Camera DT graph | `Documentation/devicetree/bindings/media/video-interfaces.yaml`; sibling `media/i2c/ovti,ov5647.yaml`, `media/i2c/imx219.yaml` |
| Unicam binding | `Documentation/devicetree/bindings/media/bcm2835-unicam.txt` (rpi tree) |
| Kbuild/Kconfig | `Documentation/kbuild/kconfig-language.rst`, `makefiles.rst`, `modules.rst` |
| Debug / test | `Documentation/admin-guide/dynamic-debug-howto.rst`, `Documentation/dev-tools/kselftest.rst`, `kunit/`, `kasan.rst` |
| Style | `Documentation/process/coding-style.rst` |
| RPi overlays | `arch/arm/boot/dts/overlays/README` |
| RPi reference drivers | `drivers/media/i2c/ov5647.c`, `imx219.c`; `drivers/media/platform/bcm2835/bcm2835-unicam.c` |

## 4. Device Tree binding

See the DT rows above.

## 5. Minimal example

Look up a symbol's header in the target tree:
`grep -n v4l2_subdev_init_finalize include/media/v4l2-subdev.h`.

## 6. Common pitfalls

- Reading latest mainline docs for an older vendor kernel: names differ.
- Citing a doc without the version it was checked against.

## 7. How to test

`tools/validate_skills.py` does not check kernel doc paths (it has no kernel
tree); verify them against a checkout when you bump the branch.

## 8. References

Books (chapter pointers; text is not copied, copyright belongs to authors):

- Corbet, Rubini, Kroah-Hartman, *Linux Device Drivers*, 3rd ed.: ch. 2
  (modules), ch. 3 (char drivers), ch. 14 (device model). Pre-DT, so use for
  concepts only.
- Love, *Linux Kernel Development*, 3rd ed.: process, memory, synchronisation
  chapters.
- Kerrisk, *The Linux Programming Interface*: userspace counterpart
  (`elinux-userspace`).
- Opdenacker et al., Bootlin training materials (online) for embedded
  kernel/DT background.
