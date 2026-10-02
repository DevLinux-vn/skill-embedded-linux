# CMake toolchain file: 64-bit ARM (aarch64) Linux target.
# Fits: Raspberry Pi Zero 2 W / 3 / 4 / 5 with a 64-bit userland,
#       Renesas RZ/G2L, R-Car (64-bit images).
# Not for 32-bit userlands: use toolchain-armv6.cmake (Zero/Zero W) or an
# armv7 file derived from it.
#
# Usage:
#   cmake -S . -B build-arm64 \
#     -DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64.cmake \
#     -DELINUX_SYSROOT=/path/to/target/sysroot      # recommended
#
# Variables (-D...): ELINUX_TRIPLE, ELINUX_SYSROOT, ELINUX_CPU
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(NOT DEFINED ELINUX_TRIPLE)
  set(ELINUX_TRIPLE aarch64-linux-gnu)   # Debian/Ubuntu package name; Yocto/Buildroot differ
endif()
set(CMAKE_C_COMPILER   ${ELINUX_TRIPLE}-gcc)
set(CMAKE_CXX_COMPILER ${ELINUX_TRIPLE}-g++)

# -mcpu is per SoC: TODO(board) confirm against the SoC's core
# (e.g. cortex-a53 for the Zero 2 W's BCM2710A1 per its DT/Arm docs).
# Leave empty to use the toolchain default (portable armv8-a).
if(DEFINED ELINUX_CPU)
  set(CMAKE_C_FLAGS_INIT   "-mcpu=${ELINUX_CPU}")
  set(CMAKE_CXX_FLAGS_INIT "-mcpu=${ELINUX_CPU}")
endif()

if(DEFINED ELINUX_SYSROOT)
  set(CMAKE_SYSROOT ${ELINUX_SYSROOT})
  # pkg-config must look only inside the sysroot, never at the host.
  set(ENV{PKG_CONFIG_DIR} "")
  set(ENV{PKG_CONFIG_LIBDIR}
      "${ELINUX_SYSROOT}/usr/lib/pkgconfig:${ELINUX_SYSROOT}/usr/lib/${ELINUX_TRIPLE}/pkgconfig:${ELINUX_SYSROOT}/usr/share/pkgconfig")
  set(ENV{PKG_CONFIG_SYSROOT_DIR} "${ELINUX_SYSROOT}")
endif()

# Programs run on the host, libraries/headers come from the target sysroot.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
