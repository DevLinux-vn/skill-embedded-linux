# One source, three adapters

Status: complete
Verified: kernel=n/a; yocto=n/a (generic); buildroot=n/a; toolchains=Ubuntu 24.04 gcc 13.2 aarch64-linux-gnu and arm-linux-gnueabihf, cmake 3.28.3, qemu-user (run on host 2026-10)

## 1. When to use / not to use

Use when an application must build the same way by hand (CMake/Make), in
Yocto and in Buildroot. Not for projects that exist in only one build
system, nor for kernel modules (their Kbuild is the core; adapters call it).

## 2. Conceptual model

```
              +-----------------+
 source tree  |  CMake core     |  options: -DENABLE_X, install rules,
 (single)     |  (CMakeLists)   |  pkg-config file, no board knowledge
              +--------+--------+
        host/dev       |        thin adapters only call the core
   cmake -S . -B ...   |   Yocto: inherit cmake (recipe: SRC_URI, DEPENDS)
                       |   Buildroot: $(eval $(cmake-package)) (.mk + Config.in)
```
- All logic, options and install rules live in CMake. Adapters pass the
  cross-compile environment and options; they never patch the sources.
- Board/hardware differences are CMake options or runtime config, not
  `#ifdef BOARD_X` (see `elinux-core/references/hal-design.md`, stub).
- `install()` honours `DESTDIR`; the adapter chooses `CMAKE_INSTALL_PREFIX`.
- Dependencies are discovered with `find_package`/pkg-config, so the same
  dependency name works against a distro sysroot, the Yocto sysroot or the
  Buildroot staging dir.

## 3. API and kernel versions

CMake >= 3.16 in the core; no kernel dependence. Adapter mechanics are in
`elinux-yocto` and `elinux-buildroot` (the latter is a stub).

## 4. Device Tree binding

Not applicable.

## 5. Minimal example

Core `CMakeLists.txt` essentials: `project()`, `add_executable()`,
`target_link_libraries()` with imported targets, `install(TARGETS ...)`,
options as `option(ENABLE_X ...)`. Developer build:
`cmake -S . -B build && cmake --build build`; cross build with a toolchain
file from `templates/`. Adapters (outline only):

```
# Yocto (elinux-yocto/templates/app_1.0.bb):  inherit cmake ; EXTRA_OECMAKE = "-DENABLE_X=ON"
# Buildroot (stub):  APP_SITE=...; APP_CONF_OPTS=-DENABLE_X=ON; $(eval $(cmake-package))
```

## 6. Common pitfalls

- Hard-coded `/usr/local`, host paths or compiler flags in CMake.
- `find_package` results cached from a host build in a reused build dir.
- Adapter patches that fork the core ("just for Yocto"): fix the core.
- Running host-built generator tools from `CMAKE_CROSSCOMPILING` builds
  without building them for the host first.
- Vendoring dependencies the sysroot already provides.

## 7. How to test

Same source, three builds: native (`TARGET=native`, unit tests), cross
with a toolchain file, and the adapter build; compare `readelf -A` and the
install tree.

## 8. References

- CMake `cmake-toolchains(7)`; Yocto `cmake.bbclass`; Buildroot manual,
  CMake package infrastructure.
