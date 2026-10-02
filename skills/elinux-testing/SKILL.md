---
name: elinux-testing
description: Test and verify embedded Linux work - kernel driver testing (dmesg, dynamic debug, KASAN, KUnit, kselftest), on-target tools (media-ctl, v4l2-ctl, i2cdetect, gpioinfo, candump), smoke-test scripts, log collection and reading dmesg/oops output. Use when asked how to verify a driver or image on the board, to write a smoke test, to diagnose a probe failure or kernel oops from logs, or to state what was and was not verified. Do NOT use for writing the driver (use elinux-kernel), build or toolchain questions (use elinux-buildsys-generic), Yocto/Buildroot packaging (use elinux-yocto / elinux-buildroot) or application design (use elinux-userspace).
---

# elinux-testing

Verification discipline for embedded Linux changes: pick the cheapest check
that can fail for the right reason, climb the pyramid, and report exactly
what was run.

## Test pyramid (cheapest first)

1. **Host static**: compile with warnings (`W=1`), `dtc` lint, shellcheck,
   `checkpatch` (kernel), schema checks where tooling exists.
2. **Host dynamic**: unit tests with a mock HAL (userspace), KUnit (kernel),
   `qemu-user` for ISA-compatible binaries.
3. **Target smoke**: boot, driver probes, devices appear, one operation
   works (`templates/smoke_test.sh`).
4. **Target functional**: real data path (frames, bytes), stress, repeat
   start/stop, unload/reload.
5. **HIL / soak**: automated runner over ssh/serial, long runs, power
   cycling.

State the highest level reached. "Compiles" is not "works".

## Workflow

1. Identify what could break: probe, resource handling, data path, teardown.
2. Choose checks per level; for kernel work read
   `references/kernel-testing.md`; for the board, `references/on-target-tools.md`.
3. Collect evidence with `scripts/collect_target_logs.sh` before and after.
4. When something fails, read the log before changing code
   (`references/log-analysis.md`).
5. Report: commands run, level reached, what is untested and why.

## Files

| Need | File |
|---|---|
| Kernel-side checks | `references/kernel-testing.md` |
| Tools to run on the board | `references/on-target-tools.md` |
| Reading dmesg and oops | `references/log-analysis.md` |
| Camera/media smoke test | `templates/smoke_test.sh` |
| Log bundle for a bug report | `scripts/collect_target_logs.sh` |
| Test pyramid, mock HAL, HIL (stubs) | `references/test-pyramid.md`, `mock-hal.md`, `hil-ssh-serial.md` |

## Rules

- Never claim a hardware result you did not observe. Say "not run on target".
- A test that cannot fail is not a test: include a negative check (driver
  absent without overlay, wrong address rejected).
- Keep tools read-only by default: `i2cdetect` write/quick probing can
  disturb some devices; prefer read-style probes and check the datasheet.
- Do not hide failures: keep the raw output in the report.
