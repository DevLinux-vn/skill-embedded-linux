# CMake toolchain file: ARMv6 hard-float Linux target.
# Fits: Raspberry Pi Zero / Zero W (BCM2835, ARM1176JZF-S).
# Does NOT fit: Zero 2 W with a 64-bit image (toolchain-aarch64.cmake) or
# with a 32-bit armv7 image (derive an armv7 file: -march=armv7-a -mfpu=neon-vfpv4).
#
# Usage:
#   cmake -S . -B build-armv6 \
#     -DCMAKE_TOOLCHAIN_FILE=toolchain-armv6.cmake \
#     -DELINUX_SYSROOT=/path/to/ARMV6/sysroot
#
# !! The sysroot must itself be built for ARMv6 (Yocto/Buildroot SDK or a
# !! copy of the target rootfs). A Debian/Ubuntu "gnueabihf" cross toolchain
# !! targets ARMv7 for its libc: code compiled with these flags may build, but
# !! linking against its libc produces binaries that fault on an ARMv6 CPU.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

if(NOT DEFINED ELINUX_TRIPLE)
  set(ELINUX_TRIPLE arm-linux-gnueabihf)
endif()
set(CMAKE_C_COMPILER   ${ELINUX_TRIPLE}-gcc)
set(CMAKE_CXX_COMPILER ${ELINUX_TRIPLE}-g++)

# -marm: some toolchains default to Thumb-2; "Thumb-1 hard-float VFP ABI" is
# unimplemented in GCC, so ARMv6 hard-float needs ARM mode. Verify these
# flags against the target (/proc/cpuinfo) and the toolchain
# (`gcc --target-help`) before relying on them: TODO(board).
set(ELINUX_ARCH_FLAGS "-marm -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard")
set(CMAKE_C_FLAGS_INIT   "${ELINUX_ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${ELINUX_ARCH_FLAGS}")

if(DEFINED ELINUX_SYSROOT)
  set(CMAKE_SYSROOT ${ELINUX_SYSROOT})
  set(ENV{PKG_CONFIG_DIR} "")
  set(ENV{PKG_CONFIG_LIBDIR}
      "${ELINUX_SYSROOT}/usr/lib/pkgconfig:${ELINUX_SYSROOT}/usr/lib/${ELINUX_TRIPLE}/pkgconfig:${ELINUX_SYSROOT}/usr/share/pkgconfig")
  set(ENV{PKG_CONFIG_SYSROOT_DIR} "${ELINUX_SYSROOT}")
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
