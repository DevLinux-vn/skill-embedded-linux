# Compiler architecture flags per SoC

Status: complete for Raspberry Pi Zero family; other SoCs are stubs (see 3)
Verified: kernel=n/a; yocto=n/a (generic); buildroot=n/a; toolchains=Ubuntu 24.04 gcc 13.2 aarch64-linux-gnu and arm-linux-gnueabihf, cmake 3.28.3, qemu-user (run on host 2026-10)

## 1. When to use / not to use

Use to pick `-march`/`-mcpu`/`-mfpu`/`-mfloat-abi` for a confirmed SoC. Not
a substitute for confirming the SoC's core: read `/proc/cpuinfo`
(`CPU part`) and the DT `compatible` on the target.

## 2. Conceptual model

Flags express the **minimum CPU the binary may assume**. Too new: SIGILL on
the board. Too old: works but slower. The libc and runtime files of the
toolchain set a floor that flags cannot lower (see `cross-compile.md`).
Prefer a plain `-mcpu=<core>` over hand-assembled `-march`+`-mfpu` when the
toolchain knows the core.

## 3. API and kernel versions

| Target | Core (confirm on target) | Flags verified to compile with gcc 13.2 | Notes |
|---|---|---|---|
| Pi Zero / Zero W | ARM1176JZF-S (ARMv6KZ) | `-marm -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard` | object tagged v6KZ/VFPv2; needs `-marm` on Thumb-default toolchains; needs ARMv6 sysroot to link |
| Pi Zero 2 W, 32-bit | Cortex-A53 in AArch32 | `-mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard` | object tagged v8 / "FP for ARMv8": too new for ARMv7-only userlands; use `-march=armv7-a -mfpu=neon-vfpv4` (verified, v7/VFPv4) to stay portable across A7/A53 |
| Pi Zero 2 W, 64-bit | Cortex-A53 | none needed; optional `-mcpu=cortex-a53` | verified `aarch64-linux-gnu-gcc -mcpu=cortex-a53` compiles |
| Pi 3/4/5, BeagleBone Black, Renesas RZ/G2L, R-Car | stub | not verified | fill from the target's core and a compile + `readelf -A` check |

Which core a board has is **not asserted here**; the table lists only what
compiled, so confirm the core on the target first.

## 4. Device Tree binding

`/proc/device-tree/compatible` and `/proc/device-tree/cpus/*/compatible`
identify the SoC and cores on the target.

## 5. Minimal example

```sh
grep -m1 'CPU part' /proc/cpuinfo; uname -m                 # on target
arm-linux-gnueabihf-gcc -marm -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard -c t.c -o t.o
arm-linux-gnueabihf-readelf -A t.o | grep -E 'CPU_arch|FP_arch|VFP_args'
```

## 6. Common pitfalls

- Thumb default + ARMv6 hard-float: "Thumb-1 hard-float VFP ABI" error.
- Soft-float vs hard-float mismatch with the rootfs libraries (link errors
  or crashes at the first float call): the rootfs defines the ABI.
- Using NEON flags on ARMv6 (no NEON).
- Enabling a Cortex-A53-specific tuning for a binary that must also run on a
  Cortex-A7 board.

## 7. How to test

Compile, `readelf -A`, execute on the target (or qemu with a matching
`-cpu`). Check the *final executable*, not only the object.

## 8. References

- GCC manual, "ARM Options" and "AArch64 Options".
- Arm Technical Reference Manuals for the cores (online).
