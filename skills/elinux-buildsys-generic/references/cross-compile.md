# Cross-compiling for embedded Linux targets

Status: complete
Verified: kernel=n/a; yocto=n/a (generic); buildroot=n/a; toolchains=Ubuntu 24.04 gcc 13.2 aarch64-linux-gnu and arm-linux-gnueabihf, cmake 3.28.3, qemu-user (run on host 2026-10)

## 1. When to use / not to use

Use when building userspace programs or libraries on an x86 host for an ARM
target. Not for kernel modules (Kbuild with `ARCH`/`CROSS_COMPILE`), and
not for Yocto/Buildroot builds where the build system owns the toolchain.

## 2. Conceptual model

Three machines: **build** (where you compile), **host** (where the binary
runs - in a cross build that is the *target*), **target** rootfs (provides
libc and libraries). A cross build needs: (a) a compiler for the target ISA
and ABI, (b) a **sysroot** containing the target's libc, headers and
libraries, (c) flags that match the CPU, (d) pkg-config pointed only at the
sysroot.

The compiler's *default* ISA comes from how the toolchain was configured.
Flags like `-mcpu` override codegen but **not** the libc and startup files
the toolchain links; the resulting executable inherits the minimum ISA of
what it links against.

## 3. API and kernel versions

Toolchain facts verified on the build host (gcc 13.2, Ubuntu 24.04):

| Check | Result |
|---|---|
| `aarch64-linux-gnu-gcc` hello world, run with `qemu-aarch64 -L /usr/aarch64-linux-gnu` | works |
| `arm-linux-gnueabihf-gcc -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard` | **fails**: "Thumb-1 'hard-float' VFP ABI" unimplemented (toolchain defaults to Thumb) |
| same with `-marm` | compiles; object tags: CPU arch v6KZ, VFPv2, hard-float |
| linking that object with the distro `gnueabihf` libc | executable is tagged **v7**: not ARMv6-safe |

No kernel version dependence.

## 4. Device Tree binding

Not applicable.

## 5. Minimal example

```sh
# 64-bit target
aarch64-linux-gnu-gcc -O2 -o app src/main.c
file app; aarch64-linux-gnu-readelf -A app | grep -E 'Tag_'    # sanity
qemu-aarch64 -L /usr/aarch64-linux-gnu ./app                     # host smoke run

# ARMv6 target: needs an ARMv6 toolchain/sysroot (Yocto/Buildroot SDK or crosstool-ng)
arm-linux-gnueabihf-readelf -A app | grep Tag_CPU_arch           # must say v6*
```

## 6. Common pitfalls

- Using a distro armhf toolchain for ARMv6: compiles with `-marm`, links to
  a v7 libc, crashes with SIGILL on the Zero. Use a toolchain/sysroot built
  for ARMv6.
- Host `/usr/include` or `/usr/lib` leaking into the build (check `-v`
  output, `ldd`/`readelf -d` NEEDED entries).
- Building a 64-bit binary for a 32-bit userland on a 64-bit kernel (the
  kernel runs it, the rootfs has no 64-bit loader) or the reverse.
- Dynamic linking against newer glibc than the target has
  (`GLIBC_x.y not found`): build against the target's sysroot or link
  statically for tests.
- Copying `-march` flags from a Pi 3/4 guide to a Zero.

## 7. How to test

1. `file`, `readelf -A` (CPU arch / FP ABI), `readelf -d` (NEEDED, RPATH).
2. `qemu-user` for aarch64/armv7 (cannot prove ARMv6 correctness: qemu
   emulates a chosen CPU, use `-cpu arm1176` for a closer check).
3. Run on the board; check `dmesg` for SIGILL/alignment traps.

## 8. References

- GCC manual, ARM options (`-march`, `-mcpu`, `-mfpu`, `-mfloat-abi`, `-marm`).
- Arm Architecture Reference Manual (ISA level of each core).
- Yocto SDK / Buildroot external toolchain documentation for ARMv6 sysroots.
