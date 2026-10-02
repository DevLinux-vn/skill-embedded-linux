# Kbuild, Kconfig and built-in vs module

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1; scaffold + olddefconfig + `make drivers/media/i2c/<name>.o` run against bcm2711_defconfig); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use when adding a driver to a kernel tree (built-in or module), choosing
`=y`/`=m`, or debugging "my driver is not built". Not for general kernel
configuration tuning, and not for out-of-tree builds of modules against an
installed kernel (use `templates/Kbuild.out-of-tree`, still a stub).

## 2. Conceptual model

- **Kconfig** defines symbols and dependencies; the chosen values land in
  `.config`. **Kbuild** (`Makefile`) maps `CONFIG_X` to objects:
  `obj-$(CONFIG_X) += file.o`.
- `tristate` symbols can be `n`, `m` (module), `y` (built-in). A symbol is
  capped by its dependencies: if something it `depends on` is `m`, it can
  be at most `m`. `select` forces another symbol on but ignores its
  dependencies, so only `select` leaf symbols with no prompt.
- **Built-in (`=y`) means the driver and everything it links against must be
  `=y`.** A built-in driver cannot call into a module's symbols.
- `module_i2c_driver()` etc. produce `module_init`/`module_exit` for `m` and
  an initcall (device_initcall level) for `y`. Built-in probe order and
  deferral therefore matter earlier in boot.
- Config sources for a board: a `*_defconfig` in the tree plus fragments
  (`scripts/kconfig/merge_config.sh`); in Yocto, `.cfg` fragments in
  `SRC_URI` (`elinux-yocto/references/kernel-recipe-and-config.md`).

## 3. API and kernel versions

| Tool / file (rpi-6.6.y) | Use |
|---|---|
| `drivers/media/i2c/Kconfig`, `Makefile` | sensor drivers live here |
| `scripts/kconfig/merge_config.sh -m .config frag.config` | merge a fragment |
| `make ARCH=arm64 olddefconfig` | resolve dependencies, writes the real result |
| `scripts/config --enable/--module CONFIG_X` | scripted edits |
| `make ARCH=arm64 drivers/media/i2c/<name>.o W=1` | compile one object |

Board defconfig for `raspberrypi0-2w-64` in Yocto: `bcm2711_defconfig`
(from `KBUILD_DEFCONFIG:raspberrypi3-64`). In it, `CONFIG_VIDEO_DEV=m`,
`V4L2_FWNODE=m`, `V4L2_CCI_I2C=m`, `VIDEO_BCM2835_UNICAM=m`.

## 4. Device Tree binding

Not applicable; but the DT compatible must be in the driver's
`of_device_id`, which is only compiled in if the Kconfig symbol is on.

## 5. Minimal example

Kconfig entry (see `templates/Kconfig.snippet`):

```
config VIDEO_MYSENSOR
	tristate "MYSENSOR sensor support"
	select V4L2_CCI_I2C
```
Makefile: `obj-$(CONFIG_VIDEO_MYSENSOR) += mysensor.o`.

Verified result of requesting the driver built-in on `bcm2711_defconfig`:

```
echo CONFIG_VIDEO_MYSENSOR=y >> .config ; make olddefconfig
  -> CONFIG_VIDEO_MYSENSOR=m        # demoted: CONFIG_VIDEO_DEV=m
```
Built-in requires the fragment to also set `CONFIG_VIDEO_DEV=y`,
`CONFIG_V4L2_FWNODE=y`, `CONFIG_V4L2_CCI_I2C=y` (and whatever else
`olddefconfig` reports as demoted). With those, `olddefconfig` kept
`CONFIG_VIDEO_MYSENSOR=y`. Always check the *final* `.config`, never the
fragment. Making `VIDEO_DEV` built-in is a platform-wide change (the V4L2
core moves from a module into the image): decide it deliberately.

## 6. Common pitfalls

- Fragment says `=y`, `.config` says `=m`: silent demotion (above).
- New Kconfig symbol inserted outside the `if VIDEO_CAMERA_SENSOR` block
  or in a different menu than its siblings.
- Makefile line added but Kconfig entry missing (or vice versa).
- `select` of a symbol with unmet dependencies: Kconfig warns, build breaks
  later.
- Built-in driver probing before its clock/regulator provider: defers, and
  if the provider is a module, defers forever.
- Editing `.config` by hand without `olddefconfig`.
- Copying a Kconfig entry that `depends on` a symbol absent in this tree.

## 7. How to test

```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
scripts/kconfig/merge_config.sh -m .config <name>.config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
grep -n 'CONFIG_VIDEO_<NAME>\|CONFIG_VIDEO_DEV\b' .config   # must be =y
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/media/i2c/<name>.o
```
(`modules_prepare` once beforehand.) On target: `zcat /proc/config.gz |
grep VIDEO_<NAME>`; built-in drivers do not appear in `lsmod`, check
`/sys/bus/i2c/drivers/<name>`.

## 8. References

- `Documentation/kbuild/kconfig-language.rst`, `makefiles.rst`,
  `modules.rst` (mainline).
- *Linux Device Drivers 3rd ed.* ch. 2 (building and running modules).
