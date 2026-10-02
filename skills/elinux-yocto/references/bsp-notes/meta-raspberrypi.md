# meta-raspberrypi notes (scarthgap)

Status: complete for raspberrypi0-2w-64 / raspberrypi0-2w; other machines are pointers
Verified: kernel=rpi-6.6.y (SRCREV e442e5c = 6.6.63, the pin used by meta-raspberrypi scarthgap; head 6.6.78); yocto=scarthgap (poky 3a3d07f + meta-raspberrypi 6ca1f75, parsed with bitbake -p, NOT built); buildroot=n/a

## 1. When to use / not to use

Use to confirm machine names, defconfigs, DTBs and versions for Raspberry Pi
Zero family builds. Not a replacement for reading the layer: re-check after
updating the layer revision.

## 2. Conceptual model

Machines are layered includes: `raspberrypi0-2w-64` -> `raspberrypi3-64` ->
base includes. That is why the Zero 2 W 64-bit uses the same `bcm2711_defconfig`
as other 64-bit machines and only differs in DTB and firmware recommends.

## 3. API and kernel versions

| Item | Verified value |
|---|---|
| Layer branch/rev | scarthgap @ 6ca1f75 (2026-07-09); `LAYERSERIES_COMPAT` = nanbield scarthgap |
| Poky | scarthgap @ 3a3d07f |
| Zero 2 W 64-bit | MACHINE `raspberrypi0-2w-64` |
| Zero 2 W 32-bit | MACHINE `raspberrypi0-2w` (includes `raspberrypi3`) |
| Zero / Zero W | MACHINE `raspberrypi0`, `raspberrypi0-wifi` |
| Kernel recipes | `linux-raspberrypi_6.1.bb`, `_6.6.bb`, `_6.12.bb`; default for scarthgap parse: 6.6.63 |
| Defconfig (64-bit Zero 2 W) | `bcm2711_defconfig` |
| DTB | `broadcom/bcm2710-rpi-zero-2.dtb` |

## 4. Device Tree binding

See `../devicetree-in-yocto.md`.

## 5. Minimal example

```sh
git clone -b scarthgap https://github.com/yoctoproject/poky
git clone -b scarthgap https://github.com/agherzan/meta-raspberrypi
source poky/oe-init-build-env build
bitbake-layers add-layer ../meta-raspberrypi
echo 'MACHINE = "raspberrypi0-2w-64"' >> conf/local.conf
bitbake -p        # parse only, as verified here
```
Host notes seen while verifying: needs a non-root user, a UTF-8 locale, and
`CONNECTIVITY_CHECK_URIS = ""` on hosts without direct internet; `gawk
chrpath diffstat texinfo lz4 zstd cpio` installed. Building (not done here)
also needs the full Yocto host dependency list.

## 6. Common pitfalls

- Choosing the 32-bit machine for a 64-bit userland plan (or reverse): the
  toolchain and rootfs follow the MACHINE.
- Mixing layer branches (layer for another release series): parse errors.
- Assuming `meta-openembedded` is absent: some recipes in this layer are
  `dynamic-layers` that only appear when it is present.

## 7. How to test

`bitbake -p` then `bitbake -e virtual/kernel | grep -E '^(PN|LINUX_VERSION|KBUILD_DEFCONFIG|SRCREV_machine)='`.

## 8. References

- `conf/machine/raspberrypi0-2w-64.conf`, `raspberrypi3-64.conf`,
  `include/rpi-base.inc`, `recipes-kernel/linux/` (meta-raspberrypi).
- Yocto Project documentation (online).
