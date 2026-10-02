# Kernel recipe, patches and config fragments (linux-raspberrypi)

Status: complete (built-in driver path); module/out-of-tree path is a stub
Verified: kernel=rpi-6.6.y (SRCREV e442e5c = 6.6.63, the pin used by meta-raspberrypi scarthgap; head 6.6.78); yocto=scarthgap (poky 3a3d07f + meta-raspberrypi 6ca1f75, parsed with bitbake -p, NOT built); buildroot=n/a

## 1. When to use / not to use

Use to add a kernel patch or config change to a Yocto image built with
meta-raspberrypi. Not for module-only recipes (`module.bbclass`, stub) or
for other BSPs.

## 2. Conceptual model

- Provider: `virtual/kernel` = `linux-raspberrypi`; recipe files
  `linux-raspberrypi_6.1.bb`, `_6.6.bb`, `_6.12.bb` coexist; the include
  `linux-raspberrypi.inc` sets `KBUILD_DEFCONFIG` per machine and
  `KCONFIG_MODE = "--alldefconfig"`.
- Source: `git://github.com/raspberrypi/linux.git;branch=rpi-6.6.y` pinned by
  `SRCREV_machine`. Your patches apply on top of that commit.
- A `.bbappend` adds `file://*.patch` and `file://*.cfg` to `SRC_URI`. `.cfg`
  files are merged into the defconfig (linux-yocto `kernel-yocto` class).
- Config merging is a *request*: unmet dependencies demote or drop options
  silently; `do_kernel_configcheck` reports mismatches.

## 3. API and kernel versions

Verified by parsing (`bitbake -p`, `bitbake -e virtual/kernel`), MACHINE
`raspberrypi0-2w-64`:

| Item | Value |
|---|---|
| `PN` / `LINUX_VERSION` | `linux-raspberrypi` / 6.6.63 |
| `SRCREV_machine` | e442e5c1ab6bff5b5460b4fc949beb72aaf77970 |
| `KBUILD_DEFCONFIG` | `bcm2711_defconfig` |
| `KERNEL_IMAGETYPE` | `Image` |
| bbappend match | `linux-raspberrypi_%` attached to the 6.1, 6.6 **and** 6.12 recipes; `_6.6` attaches to one |

Driver-in-tree check at that SRCREV (compiled, not booted): template
instantiated with the scaffold script built `drivers/media/i2c/<name>.o`
(W=1) and the overlay `.dtbo`, and `olddefconfig` kept the symbol `=y` only
with `VIDEO_DEV`, `V4L2_FWNODE`, `V4L2_CCI_I2C` built-in.

## 4. Device Tree binding

The overlay source is part of the same patch (`overlays/<name>-overlay.dts`
plus its `overlays/Makefile` entry); see `devicetree-in-yocto.md`.

## 5. Minimal example

`templates/linux-raspberrypi_6.6.bbappend`:

```
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-media-i2c-add-mycam-sensor-driver.patch file://mycam.cfg"
```
Making the patch at the pinned commit:

```sh
git -C rpi-linux checkout <SRCREV_machine>
skills/elinux-kernel/scripts/scaffold_sensor_driver.sh --name mycam --vendor acme --kernel-dir rpi-linux
git -C rpi-linux add drivers arch && git -C rpi-linux commit -m "media: i2c: add mycam sensor driver"
git -C rpi-linux format-patch -1 -o layer/recipes-kernel/linux/files/
```
`mycam.cfg` = the `CONFIG_*` lines from the scaffold's `mycam.config` (no
comments needed).

## 6. Common pitfalls

- `%` bbappend applied to a kernel version the patch was not written for.
- Patch made against branch head; fails on the pinned `SRCREV_machine`
  (context drift).
- `.cfg` lists only `CONFIG_VIDEO_MYCAM=y`: demoted to `=m`, driver is not in
  the image at all if modules are not packaged or autoloaded.
- Changing `VIDEO_DEV` to built-in without noticing it is a platform-wide change.
- Forgetting `FILESEXTRAPATHS`: `file://` not found.
- Debugging the running image without checking the *built* `.config`
  (`bitbake -e`, `${B}/.config`, or `/proc/config.gz` on target).

## 7. How to test

```sh
source poky/oe-init-build-env build
skills/elinux-yocto/scripts/check_layer.sh --layer ../meta-camera \
   --patch 0001-media-i2c-add-mycam-sensor-driver.patch --cfg mycam.cfg --overlay mycam.dtbo
bitbake -c kernel_configcheck virtual/kernel      # on a build host
```
The check script parses only. Building and booting are separate steps.

## 8. References

- meta-raspberrypi: `recipes-kernel/linux/linux-raspberrypi.inc`,
  `linux-raspberrypi_6.6.bb`.
- Yocto Linux Kernel Development Manual (online): patches, config fragments,
  `kernel_configcheck`.
- Yocto Reference Manual: `FILESEXTRAPATHS`, `SRC_URI`.
