# Sysroot and pkg-config

Status: complete
Verified: kernel=n/a; yocto=n/a (generic); buildroot=n/a; toolchains=Ubuntu 24.04 gcc 13.2 aarch64-linux-gnu and arm-linux-gnueabihf, cmake 3.28.3, qemu-user (run on host 2026-10)

## 1. When to use / not to use

Use when the build needs target libraries (libgpiod, libcamera, openssl...).
Not needed for self-contained code that only uses the toolchain's libc.

## 2. Conceptual model

A **sysroot** is a directory laid out like the target's `/` (`usr/include`,
`usr/lib`, `lib`). Sources: copy from the running target (rsync of
`/lib /usr/include /usr/lib /usr/share/pkgconfig`), the Yocto SDK
(`populate_sdk`), the Buildroot staging dir, or a toolchain vendor tarball.
It must come from the **same build** as the target rootfs: library versions
and ISA must match.

pkg-config must be told to look only there:
`PKG_CONFIG_LIBDIR=<sysroot>/usr/lib/pkgconfig:...`,
`PKG_CONFIG_SYSROOT_DIR=<sysroot>`, and `PKG_CONFIG_DIR` cleared.

## 3. API and kernel versions

No kernel dependence. Debian multiarch puts libraries and `.pc` files under
`usr/lib/<triple>/`; Yocto/Buildroot use `usr/lib`. The toolchain files here
list both paths.

## 4. Device Tree binding

Not applicable.

## 5. Minimal example

```sh
rsync -a --safe-links pi@target:/{lib,usr/include,usr/lib,usr/share/pkgconfig} sysroot/
# absolute symlinks inside the copy must be made relative (e.g. with the
# "sysroot-relativelinks" approach) or they point at the host.
cmake -S . -B b -DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64.cmake -DELINUX_SYSROOT=$PWD/sysroot
```

## 6. Common pitfalls

- Absolute symlinks in a rsync'd sysroot resolve to the **host**.
- Sysroot taken from a different image version than the one deployed.
- Missing `-dev` content on the target (headers absent): install dev
  packages on the target before copying, or use the SDK.
- RPATH/RUNPATH pointing into the sysroot on the host: strip or set
  `CMAKE_SKIP_RPATH`.
- `.pc` files with absolute `prefix=`: need `PKG_CONFIG_SYSROOT_DIR`.

## 7. How to test

`pkg-config --cflags --libs <lib>` under the exported variables must print
paths inside the sysroot only; `readelf -d` of the result lists only
libraries that exist on the target.

## 8. References

- `man pkg-config`; CMake `CMAKE_SYSROOT`.
- Yocto `populate_sdk`, Buildroot staging directory docs.
