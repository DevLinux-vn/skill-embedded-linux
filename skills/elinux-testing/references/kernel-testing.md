# Kernel-side testing

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (Documentation paths checked in that tree; options not run on a board); yocto=scarthgap (kernel config via .cfg fragments, see elinux-yocto); buildroot=n/a

## 1. When to use / not to use

Use to verify a driver or DT change inside the kernel: probe/remove paths,
locking, memory and sleeping bugs. Not for userspace testing, and not as
proof of correct hardware behaviour (a driver can be clean under KASAN and
still program the wrong register).

## 2. Conceptual model

Layers of kernel checking, from cheap to costly:

1. **Build checks**: `W=1`, `C=1` (sparse), `make checkpatch`,
   `scripts/checkpatch.pl` on the patch, `dt_binding_check` for bindings.
2. **Runtime log**: `dmesg` for probe messages; **dynamic debug** turns on
   `dev_dbg` per file/function without rebuilding
   (`echo 'file <name>.c +p' > /sys/kernel/debug/dynamic_debug/control`),
   needs `CONFIG_DYNAMIC_DEBUG`.
3. **Debug kernel options** (test images only; they cost speed and memory,
   which a Pi Zero has little of): `KASAN` (memory errors, large RAM cost,
   check support for the arch/config), `DEBUG_ATOMIC_SLEEP`,
   `PROVE_LOCKING`/lockdep, `DEBUG_OBJECTS`, `KMEMLEAK`, `FAULT_INJECTION`.
4. **KUnit** (`Documentation/dev-tools/kunit/`): in-kernel unit tests for
   pure logic (parsers, register math) on host via UML or on target.
5. **kselftest** (`Documentation/dev-tools/kselftest.rst`): userspace
   programs shipped with the kernel for existing subsystems.
6. **Lifecycle tests**: repeat bind/unbind, module load/unload, stream
   start/stop N times, probe with each resource missing (error paths).
7. **Tracing**: `ftrace`/`trace-cmd`, `trace_printk`, tracepoints for timing
   and ordering problems.

## 3. API and kernel versions

Option names above exist in rpi-6.6.y Kconfig as of verification;
availability varies by architecture and config (`bcm2711_defconfig` does
not enable them). Enable via config fragment, then confirm in the final
`.config` (`elinux-kernel/references/fundamentals/kbuild-kconfig.md`).
KASAN and large debug options may not fit a 512 MB board comfortably:
measure `free -m` first.

## 4. Device Tree binding

`make dt_binding_check` / `dtbs_check` (dt-schema) validate bindings and
DTs; not run in this repo's validation (needs `dtschema` and a kernel tree).

## 5. Minimal example

Driver bring-up checklist for a camera sensor (all on target):

```sh
dmesg -C; modprobe <name> 2>/dev/null || true       # or reboot for built-in
dmesg | grep -i <name>                               # chip ID, probe result
echo 'file <name>.c +p' > /sys/kernel/debug/dynamic_debug/control
# repeat 20x: start/stop stream, watch dmesg for warnings
for i in $(seq 20); do v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=3 --stream-to=/dev/null || break; done
# unbind/rebind (built-in or module) to test remove + probe error paths
echo <i2c-dev> > /sys/bus/i2c/drivers/<name>/unbind
echo <i2c-dev> > /sys/bus/i2c/drivers/<name>/bind
```

## 6. Common pitfalls

- Declaring success from "probe printed OK" without exercising stream,
  suspend, unbind.
- Debug options left in the production image.
- No negative test: the error path after `v4l2_async_register_subdev_sensor`
  failing is rarely exercised, and is where leaks live. Use fault
  injection or deliberately wrong DT values.
- Sleeping calls in atomic context only show up with
  `DEBUG_ATOMIC_SLEEP`.
- Built-in driver tests that need a reboot per iteration: use
  unbind/bind instead.
- KASAN on a board without enough RAM: OOM looks like a driver bug.

## 7. How to test

This chapter is the test method; evidence is the `dmesg` plus the command
transcript. `scripts/collect_target_logs.sh` bundles it.

## 8. References

- `Documentation/admin-guide/dynamic-debug-howto.rst`,
  `Documentation/dev-tools/kasan.rst`, `Documentation/dev-tools/kunit/`,
  `Documentation/dev-tools/kselftest.rst`, `Documentation/process/submitting-patches.rst`.
- *Linux Kernel Development* (Love), debugging chapter.
