---
name: elinux-yocto
description: Package and build embedded Linux changes with Yocto Project and meta-raspberrypi - layers, bbappends for linux-raspberrypi (built-in drivers, config fragments, device tree overlays), local.conf and config.txt wiring, image contents and parse-time checks. Use when the task is how to get a kernel patch, overlay or app into a Yocto image, or why a Yocto kernel/DT change did not take effect. Do NOT use for writing the kernel driver or overlay content (use elinux-kernel), plain CMake/Make cross builds (use elinux-buildsys-generic), Buildroot (use elinux-buildroot), or on-target verification (use elinux-testing). Currently covers the kernel-change path for the Raspberry Pi Zero 2 W; other BSPs and recipe types are stubs.
---

# elinux-yocto

Yocto packaging of work done with `elinux-kernel`. Needs the target profile
from `elinux-core`. Written and parse-checked for **scarthgap +
meta-raspberrypi, MACHINE `raspberrypi0-2w-64`**; everything else says
`Status: stub`.

## Workflow: a built-in kernel driver + overlay

1. Produce the change in a kernel tree at the exact commit Yocto fetches:
   read `SRCREV_machine` from `recipes-kernel/linux/linux-raspberrypi_6.6.bb`
   (`bitbake -e virtual/kernel | grep ^SRCREV_machine`), check out that commit,
   run `elinux-kernel/scripts/scaffold_sensor_driver.sh`, fill the TODOs,
   commit, `git format-patch -1`.
2. In your layer: `linux-raspberrypi_6.6.bbappend` adds the patch and a
   config fragment (`templates/linux-raspberrypi_6.6.bbappend`).
3. Ship the overlay: add `overlays/<name>.dtbo` to
   `RPI_KERNEL_DEVICETREE_OVERLAYS` and enable it with `RPI_EXTRA_CONFIG`
   (`templates/local.conf.snippet`, `references/devicetree-in-yocto.md`).
4. Static check: `scripts/check_layer.sh --layer ... --patch ... --cfg ...
   --overlay ...` (parse-time; says nothing about booting).
5. Build on a real build host (`bitbake <image>`), flash, then
   `elinux-testing`. Say plainly that step 5 was not run if it was not.

## Files

| Need | File |
|---|---|
| Kernel recipe, patches, config fragments | `references/kernel-recipe-and-config.md` |
| Overlays, `config.txt`, DTB list | `references/devicetree-in-yocto.md` |
| meta-raspberrypi facts (machines, defconfig, versions) | `references/bsp-notes/meta-raspberrypi.md` |
| Common failures | `references/pitfalls.md` |
| Layer, bbappend, local.conf templates | `templates/` |
| Parse-time checks | `scripts/check_layer.sh` |
| Layer structure, recipe anatomy, SDK, images | stubs in `references/` |

## Rules

- Never claim an image works from a parse. State: parsed / built / booted.
- Pin the bbappend to the recipe version (`_6.6`), not `%`: meta-raspberrypi
  carries 6.1, 6.6 and 6.12 kernel recipes side by side.
- The patch must apply to `SRCREV_machine`, not to branch head; verify with
  `git apply --check` at that commit.
- Config fragments are requests: confirm the final `.config` (`kernel_configcheck`).
- Keep hardware facts in the patch/overlay (`TODO(board)`), not in recipes.
- Application code stays in the CMake core; the recipe only calls it
  (`elinux-buildsys-generic/references/one-source-three-adapters.md`).
