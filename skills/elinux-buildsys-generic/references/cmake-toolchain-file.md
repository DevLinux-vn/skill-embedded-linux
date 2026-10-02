# CMake toolchain files

Status: complete
Verified: kernel=n/a; yocto=n/a (generic); buildroot=n/a; toolchains=Ubuntu 24.04 gcc 13.2 aarch64-linux-gnu and arm-linux-gnueabihf, cmake 3.28.3, qemu-user (run on host 2026-10)

## 1. When to use / not to use

Use to cross-build a CMake project from the host. Not for building *inside*
Yocto (the `cmake` bbclass generates its own toolchain file) or Buildroot
(`cmake-package` does the same).

## 2. Conceptual model

A toolchain file sets `CMAKE_SYSTEM_NAME`/`PROCESSOR`, the compilers, the
sysroot and the find-root modes, **before** `project()`. It must be passed at
configure time (`-DCMAKE_TOOLCHAIN_FILE=`). The three find modes make
`find_library/include/package` search the sysroot while `find_program` still
finds host tools (`protoc`, code generators).

## 3. API and kernel versions

CMake 3.28.3 used for verification; features used (`CMAKE_SYSROOT`,
`CMAKE_FIND_ROOT_PATH_MODE_*`, `*_FLAGS_INIT`) are old and stable (>= 3.0 /
3.9).

## 4. Device Tree binding

Not applicable.

## 5. Minimal example

```sh
cmake -S . -B build-arm64 \
  -DCMAKE_TOOLCHAIN_FILE=skills/elinux-buildsys-generic/templates/toolchain-aarch64.cmake \
  -DELINUX_SYSROOT=/path/to/sysroot
cmake --build build-arm64
file build-arm64/app
```
Templates: `templates/toolchain-aarch64.cmake`, `templates/toolchain-armv6.cmake`.
Both configured, built and checked with `file` on the verification host.

## 6. Common pitfalls

- Setting flags in `CMAKE_C_FLAGS` of the project instead of `*_FLAGS_INIT`
  in the toolchain file (lost on cache reuse or overridden).
- Changing the toolchain file in an existing build dir: CMake caches the
  compiler; use a fresh build dir per target.
- `CMAKE_SYSTEM_PROCESSOR` wrong: projects that branch on it pick x86 code.
- `try_run` checks cannot execute target binaries: provide results with
  `CMAKE_CROSSCOMPILING_EMULATOR` (qemu) or cache variables.
- pkg-config picking host `.pc` files (see `sysroot-pkgconfig.md`).

## 7. How to test

`cmake -S . -B b -DCMAKE_TOOLCHAIN_FILE=... && cmake --build b`, then
`file`/`readelf -A` on the result (`tools/validate_skills.py` does this when
cross compilers are installed).

## 8. References

- CMake manual: `cmake-toolchains(7)`.
- `elinux-buildsys-generic/templates/`.
