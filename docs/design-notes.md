# Design notes

## Decisions

- Seven skills: `elinux-core` (router, target profile), `elinux-kernel`,
  `elinux-userspace`, `elinux-yocto`, `elinux-buildroot`,
  `elinux-buildsys-generic`, `elinux-testing`.
- Progressive disclosure: small `SKILL.md`, `references/` loaded on demand.
- One source, three adapters: CMake core; Yocto recipe and Buildroot package
  only call into it.
- Slice #1 (eval #1): V4L2 sensor driver for a camera on a Raspberry Pi
  Zero-family board.
- User choices for slice #1: **Zero 2 W, 64-bit (`raspberrypi0-2w-64`),
  OV5647 written from scratch, built-in driver, Yocto (meta-raspberrypi),
  kernel rpi-6.6.y, English content, repo root = tree root.**

## Facts found while building the slice (all verified against sources)

- rpi-6.6.y already has `ov5647.c`, `CONFIG_VIDEO_OV5647` and an
  `ov5647` overlay: a new driver must use another name/symbol/compatible.
  Hence the *applicability check* in `elinux-kernel/SKILL.md`.
- `bcm2711_defconfig` (used by `raspberrypi0-2w-64`) has `VIDEO_DEV=m`;
  a built-in sensor needs `VIDEO_DEV`, `V4L2_FWNODE`, `V4L2_CCI_I2C` built-in
  or `olddefconfig` demotes it to `=m` silently.
- meta-raspberrypi ships `linux-raspberrypi_6.1/6.6/6.12`; a `%` bbappend
  attaches to all three. The template is `_6.6`.
- The default `RPI_KERNEL_DEVICETREE_OVERLAYS` list has `imx219` but not
  `ov5647`; custom overlays must be added globally.
- `fdtoverlay` rejects a label on an `__overlay__` node (`FDT_ERR_NOTFOUND`)
  although the Raspberry Pi firmware accepts it; templates avoid it so they
  can be tested.
- Distro `arm-linux-gnueabihf` toolchains default to Thumb (fails for ARMv6
  hard-float without `-marm`) and link an ARMv7 libc (executables tagged v7).

## Known gaps

- Nothing was built into an image or booted on a board. Yocto was parsed
  (`bitbake -p`, `bitbake -e`) only; kernel patch compiled and overlay built at
  the Yocto-pinned commit.
- Sensor register tables are intentionally absent (`TODO(datasheet)`).
- `dt_binding_check` (dt-schema) not run; `skills/elinux-kernel/templates/binding.yaml` is only
  YAML-parsed.
- Stubs: userspace, buildroot, other boards, most kernel subsystems.
- `.claude-plugin/plugin.json` vs root `plugin.json`: layout not verified
  against the current plugin spec.
