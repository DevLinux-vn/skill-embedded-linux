# Reading dmesg and oops output

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (general log semantics; no board log was captured in this repo); yocto=n/a; buildroot=n/a

## 1. When to use / not to use

Use when a probe fails, a device is missing, or the kernel prints a warning
or oops. Not for application crashes (userspace tools: gdb, core dumps).

## 2. Conceptual model

Read **first error, in time order**; later messages are usually
consequences. Probe failures are one line with an errno:

| Message / errno | Typical cause |
|---|---|
| `probe of X failed with error -517` (`-EPROBE_DEFER`) | a dependency (clock, regulator, GPIO, graph peer) is not ready yet; check `devices_deferred` |
| `-ENODEV` | identity check failed (chip ID, wrong address, not powered) or no match |
| `-EINVAL` | DT property missing/invalid (lanes, link-frequencies, clock rate) |
| `-EREMOTEIO` / `-ENXIO` (I2C) | no ACK: wrong address/bus, power or clock missing |
| `-EBUSY` | resource already claimed (GPIO, I2C address, region) |
| `-ENOMEM` | allocation failed; check CMA/memory on small boards |

An **oops** shows: the failing instruction/address (`Unable to handle kernel
NULL pointer dereference at ...`), the call trace (innermost first), the
modules loaded and the taint flags. Map `symbol+0xoff/0xsize` to source with
`addr2line -e vmlinux` or `scripts/faddr2line vmlinux sym+off/size`.
Lockdep, KASAN and sleep-in-atomic splats name the exact function pair.

## 3. API and kernel versions

Tools in the kernel tree: `scripts/decode_stacktrace.sh`, `scripts/faddr2line`.
They need the `vmlinux` (with debug info) that matches the running kernel.

## 4. Device Tree binding

Missing/invalid property errors are printed by the driver's own message or
`OF:` lines; compare the node in `dtc -I fs -O dts /proc/device-tree`.

## 5. Minimal example

```sh
dmesg | grep -i -E 'probe of|error|fail|warn|oops|BUG'
cat /sys/kernel/debug/devices_deferred
./scripts/faddr2line vmlinux my_driver_probe+0x1c4/0x2a0
```

## 6. Common pitfalls

- Fixing the last message instead of the first.
- Decoding an oops against a different build than the running kernel.
- Ignoring taint flags (an out-of-tree or proprietary module changes how
  the report will be received).
- Missing earlier boot messages: they scroll off; use `journalctl -k -b`,
  serial console, or `dmesg` right after boot.
- Treating `-EPROBE_DEFER` as an error when it resolves a moment later.

## 7. How to test

Reproduce with `dmesg -C` first, change one thing, compare. Capture with
`scripts/collect_target_logs.sh`.

## 8. References

- `Documentation/admin-guide/bug-hunting.rst`,
  `Documentation/admin-guide/tainted-kernels.rst` (mainline).
