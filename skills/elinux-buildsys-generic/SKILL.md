---
name: elinux-buildsys-generic
description: Cross-compile embedded Linux userspace and kernel modules with plain Make or CMake - toolchain files, -march/-mcpu/-mfpu flags per SoC (ARMv6 Pi Zero vs Cortex-A53 vs aarch64), sysroot and pkg-config, and the "one source, three adapters" layout where CMake core is called by Yocto recipes and Buildroot packages. Use when the task is how to build, which toolchain or flags, or how to structure a build so Yocto/Buildroot can reuse it. Do NOT use for writing Yocto recipes (use elinux-yocto), Buildroot packages (use elinux-buildroot), kernel driver code (use elinux-kernel), application logic (use elinux-userspace) or on-target testing (use elinux-testing).
---

# elinux-buildsys-generic

Build-system mechanics that are independent of Yocto/Buildroot. Needs the
target profile from `elinux-core` (SoC, userland bitness, kernel version).

## Decision first: which ABI?

The compiler target follows the **rootfs bitness and ISA**, not the board name.

| Target rootfs | Toolchain triple (typical) | Toolchain file |
|---|---|---|
| Pi Zero / Zero W, 32-bit (ARMv6, hard-float) | `arm-linux-gnueabihf` **with an ARMv6 sysroot** | `templates/toolchain-armv6.cmake` |
| Pi Zero 2 W / 3 / 4 / 5, 64-bit | `aarch64-linux-gnu` | `templates/toolchain-aarch64.cmake` |
| Pi Zero 2 W 32-bit | armv7 hard-float | derive from the armv6 file (flags in `march-flags-per-soc.md`) |
| BeagleBone Black (Cortex-A8), Renesas | stubs | see `march-flags-per-soc.md` |

If the bitness or ISA is unconfirmed, ask; a wrong choice builds fine and
fails (or silently misbehaves) on the board.

## Workflow

1. Confirm ABI from the profile; read `references/cross-compile.md`.
2. Get a **sysroot** that matches the target rootfs
   (`references/sysroot-pkgconfig.md`). Distro cross-compilers ship their
   own sysroot; it is not your target's.
3. Use the toolchain file or `Makefile.cross` from `templates/`.
4. Check the *linked* result: `file` + `readelf -A` (CPU arch tag, FP ABI),
   then run under `qemu-user` if the ISA allows, else on the board.
5. Keep the core buildable by CMake with no Yocto/Buildroot knowledge
   (`references/one-source-three-adapters.md`).

## References and templates

| Need | File |
|---|---|
| Cross-compile concepts and checks | `references/cross-compile.md` |
| CMake toolchain files | `references/cmake-toolchain-file.md` |
| Sysroot, pkg-config, `--sysroot` | `references/sysroot-pkgconfig.md` |
| `-march`/`-mcpu` per SoC | `references/march-flags-per-soc.md` |
| CMake core + Yocto/Buildroot adapters | `references/one-source-three-adapters.md` |
| Toolchain files, Makefile | `templates/toolchain-*.cmake`, `templates/Makefile.cross` |

## Rules

- Do not hard-code CPU flags from memory: take them from the SoC's core as
  confirmed on the target (`/proc/cpuinfo`, DT `compatible`) and verify with
  `readelf -A` on the output.
- Never let host headers or libraries leak in: sysroot, `pkg-config` libdir
  and `CMAKE_FIND_ROOT_PATH_MODE_*` must point at the target.
- Out-of-tree kernel modules are **not** built with these toolchain files:
  they use the kernel's Kbuild with `ARCH=` / `CROSS_COMPILE=` against the
  exact kernel tree/headers that runs on the target (`elinux-kernel`).
- Report which checks ran: compiled, ISA tag verified, executed under qemu,
  executed on hardware.
