# Target profile: questions to collect

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78; yocto=scarthgap (meta-raspberrypi); buildroot=n/a

## 1. When to use / not to use

Use at the start of every embedded Linux task and whenever an answer changes
(new board revision, new kernel branch). Do not use it as a questionnaire to
send in full: ask only what is missing and cannot be read from the repo.

## 2. Conceptual model

A target profile is the set of facts that make advice *true* for one device.
Each field has a **source of truth** and a **how to read it** command. Prefer
reading from the device over asking.

| Field | Why it matters | Read it from the target |
|---|---|---|
| Board + revision | SoC, connectors, DT file | `cat /proc/device-tree/model`; `cat /proc/cpuinfo` (Revision) |
| SoC / CPU arch | ISA, `-march`, ABI | `uname -m`; `lscpu` |
| Userland bitness | 32 vs 64-bit libs, toolchain | `getconf LONG_BIT`; `file /bin/sh` |
| Kernel version/branch | API surface of drivers | `uname -r`; `zcat /proc/config.gz \| head` |
| Kernel config | is the subsystem/driver enabled, `=y` or `=m` | `zcat /proc/config.gz \| grep CONFIG_X` |
| Boot path | how DT/overlays/kernel are loaded | `/boot/firmware/config.txt`, U-Boot env, `extlinux.conf` |
| OS / build system | how artifacts are produced and deployed | repo contents (see `detect_build_system.sh`) |
| Active DT | real pins, buses, labels | `dtc -I fs -O dts /proc/device-tree` |
| Hardware under work | connector, module, sensor, chip | schematic, datasheet, module docs |
| Access | ssh, serial console, JTAG, power cycling | ask the user |
| Rollback | can you recover from a bad kernel/DT? | see `safety-checklist.md` |

## 3. API and kernel versions

Not applicable (no kernel API). Record the **kernel branch and exact
version** in the profile; every later reference states the version it was
checked against and the mismatch risk is yours to flag.

## 4. Device Tree binding

Not applicable. The profile only records *which* DT is active and how
overlays are loaded; see `elinux-kernel/references/device-model/overlays.md`.

## 5. Minimal example

```
board:        Raspberry Pi Zero 2 W (rev from /proc/cpuinfo)
soc/cpu:      BCM2710A1, Cortex-A53, aarch64 capable
userland:     64-bit (Yocto MACHINE=raspberrypi0-2w-64)
kernel:       rpi-6.6.y (6.6.x), built by Yocto linux-raspberrypi
build system: Yocto scarthgap + meta-raspberrypi
hardware:     OV5647 camera on the CSI camera connector
driver form:  built-in (=y) in the kernel
access:       ssh + serial console   rollback: second SD card
open items:   schematic of camera module (I2C address, lanes, supplies)
```

## 6. Common pitfalls

- Assuming "Zero" means ARMv6: only Zero / Zero W are; Zero 2 W is a
  Cortex-A53.
- Reading `uname -m` of the **build host** instead of the target.
- Trusting a board's documentation for a different revision.
- Mixing kernel versions between the running image and the tree used to
  build the module (`vermagic` mismatch).
- Skipping the schematic: lane count, I2C bus and address, supply names are
  per camera module.

## 7. How to test

`skills/elinux-core/scripts/detect_build_system.sh .` on the repo, and the
read-from-target commands above over ssh. A profile with unresolved
`TODO(board)` items is allowed; state them explicitly in the final answer.

## 8. References

- Raspberry Pi kernel tree overlay README:
  `arch/arm/boot/dts/overlays/README` (rpi-6.6.y).
- `Documentation/devicetree/usage-model.rst` (mainline).
