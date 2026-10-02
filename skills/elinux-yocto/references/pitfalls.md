# Yocto pitfalls (kernel-change path)

Status: complete (limited to what was verified)
Verified: kernel=rpi-6.6.y (SRCREV e442e5c = 6.6.63, the pin used by meta-raspberrypi scarthgap; head 6.6.78); yocto=scarthgap (poky 3a3d07f + meta-raspberrypi 6ca1f75, parsed with bitbake -p, NOT built); buildroot=n/a

## 1. When to use / not to use

Use when a kernel/DT change made it into the metadata but not the image.
Not a general Yocto troubleshooting guide.

## 2. Conceptual model

Failure points, in order: recipe attachment -> fetch -> patch -> config ->
compile -> deploy -> boot files -> firmware. Check them in that order.

## 3. API and kernel versions

As in `kernel-recipe-and-config.md`.

## 4. Device Tree binding

Not applicable.

## 5. Minimal example

```sh
bitbake-layers show-appends | grep -A2 linux-raspberrypi   # attached to which recipe?
bitbake -e virtual/kernel | grep -E '^(SRC_URI|KERNEL_DEVICETREE)='
bitbake -c cleansstate virtual/kernel && bitbake virtual/kernel
```

## 6. Common pitfalls

| Symptom | Check |
|---|---|
| bbappend ignored | filename must match the recipe (`_6.6`), layer in `bblayers.conf`, `BBFILES` pattern covers `recipes-*/*/*.bbappend` |
| Patch fails | made against branch head, not `SRCREV_machine` |
| Driver absent | symbol demoted to `=m` or dropped: read the built `.config` |
| Overlay missing from boot partition | not in `RPI_KERNEL_DEVICETREE_OVERLAYS` (set globally) |
| Overlay present, not applied | no `dtoverlay=` line in generated `config.txt` |
| Works after manual copy, not after bitbake | stale sstate: `cleansstate` the kernel and boot-file recipes |
| Parse error after layer update | layer branch vs release series mismatch |

## 7. How to test

`scripts/check_layer.sh`, then a real build and boot; keep the
`bitbake -e` output with the report.

## 8. References

- Yocto Project Reference Manual, Kernel Development Manual (online).
