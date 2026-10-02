# Safety checklist: panics, locking, storage, rollback

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (general kernel practice; no board fault was induced in this repo); yocto=scarthgap (boot flow notes from meta-raspberrypi files read); buildroot=n/a

## 1. When to use / not to use

Run before any change that touches the kernel, device tree, boot files,
storage or power/clock/regulator setup. Skip for pure userspace edits that
cannot affect boot or storage (still keep a copy of what you change).

## 2. Conceptual model

Embedded failures are costly because the device may not come back: no
console, no network, SD card is the only recovery. Decide **before** writing
code: what is the worst outcome, how would I notice, how do I recover?

| Risk | Typical trigger | Mitigation |
|---|---|---|
| Kernel panic at boot | built-in driver bug, bad DT, missing rootfs driver | keep a known-good kernel/DTB pair selectable; test as a module or overlay first when possible; serial console attached |
| Device never boots | wrong `config.txt`/overlay line, corrupt boot partition | second SD card with a good image; edit boot files on the card from a PC |
| Lockup / hang | sleeping in atomic context, lock-order inversion, waiting forever on hardware | `DEBUG_ATOMIC_SLEEP`, lockdep on test images; every wait has a timeout |
| Memory corruption | use-after-free in remove/error paths, double free with `devm_*` | unwind in reverse order; KASAN on test images |
| Hardware damage | wrong voltage/GPIO direction, driving a line that is an output elsewhere | schematic first; start GPIOs as inputs or in the safe state; never guess pin numbers |
| Storage corruption | power loss during writes, no fsync, wearing SD | read-only rootfs or overlay for field units, `sync`, avoid logging to flash at high rate |
| Bricking via fuses/bootloader | OTP, eMMC boot partitions, bootloader updates | do not touch unless the task is about it; read the vendor procedure |

Locking basics for driver code: protect shared state with one clear lock,
never sleep under a spinlock or in an interrupt handler, use `devm_*` and
mirror teardown order of setup, and keep the control-handler/state lock
relationship explicit (`elinux-kernel/references/subsystems/v4l2-subdev-sensor.md`).

## 3. API and kernel versions

Debug options named here are mainline Kconfig symbols (`DEBUG_ATOMIC_SLEEP`,
`PROVE_LOCKING`, `KASAN`); availability and memory cost vary by arch and
board RAM (see `elinux-testing/references/kernel-testing.md`).

## 4. Device Tree binding

A wrong DT can prevent boot. Apply overlays only through a path you can
revert (remove the `dtoverlay=` line from the boot partition); do not edit
the base DTB in place on the only copy.

## 5. Minimal example

Pre-change checklist (copy into the answer when relevant):

```
[ ] Console access (serial or ssh) and a way to power cycle
[ ] Known-good SD image / kernel+DTB pair saved
[ ] Schematic or datasheet open for every pin/voltage touched
[ ] Change reversible by editing files on the boot partition
[ ] Test as module/overlay before making it built-in
[ ] Debug options planned for the first run (not for production)
[ ] What "success" and "failure" look like in dmesg
```

## 6. Common pitfalls

- Making a driver built-in before it works as a module: a probe crash now
  prevents boot.
- Testing only the happy path; the error path after partial setup is where
  crashes happen.
- No timeout on a hardware wait.
- Logging to the SD card at high rate on a deployed device.
- Changing several things at once so a boot failure has no single cause.

## 7. How to test

Boot with the console attached; trigger probe/remove and error paths
(`elinux-testing/references/kernel-testing.md`); power-cycle test the
recovery path once so you know it works.

## 8. References

- `Documentation/admin-guide/bug-hunting.rst`, `Documentation/dev-tools/kasan.rst`,
  `Documentation/locking/` (mainline).
- *Linux Kernel Development* (Love): synchronisation chapters.
