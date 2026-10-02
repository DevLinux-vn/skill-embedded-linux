# I2C client drivers

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use for a driver bound to a chip on an I2C/SMBus bus (sensors, PMICs,
codecs). Not for the I2C *controller* driver (platform driver, not covered),
nor for userspace access through `/dev/i2c-N` (`elinux-userspace`).

## 2. Conceptual model

- The bus has a **controller** (adapter) and **clients** (chips). A client is
  created from a DT child node of the bus node; `reg` is the 7-bit address.
- The driver matches by `of_match_table` (DT compatible) and optionally
  `i2c_device_id`. Probe runs when node and driver meet, in either order.
- Register access: prefer `regmap` (or `v4l2-cci` over regmap for camera
  sensors) over raw `i2c_transfer()`; it gives endianness, caching and
  debugfs for free.
- **Which bus is "the camera bus"** is board wiring. On Raspberry Pi the
  camera connector's I2C is reached through a mux node (`i2c0mux`, child
  `i2c_csi_dsi`) owned by the VideoCore side; the bus *number* in
  `/dev/i2c-N` can change between boots and images. Reference the bus by DT
  label, never by number.

## 3. API and kernel versions

| Item | rpi-6.6.y |
|---|---|
| `struct i2c_driver.probe` | `int (*probe)(struct i2c_client *)` |
| `.remove` | returns `void` |
| Device tables | `MODULE_DEVICE_TABLE(of, ...)`; omit `i2c_device_id` unless needed |
| Helpers | `devm_regmap_init_i2c()`, `devm_cci_regmap_init_i2c()`, `module_i2c_driver()` |
| Probe-time errors | `dev_err_probe()` |

Older kernels used a two-argument probe and `int` remove; check the target.
**[UNVERIFIED]** exact release of each change; confirm in the target's
`include/linux/i2c.h`.

## 4. Device Tree binding

```
&<bus-label> {
	#address-cells = <1>;
	#size-cells = <0>;
	chip@<addr> {
		compatible = "<vendor>,<chip>";
		reg = <0x<addr>>;     /* TODO(datasheet)/TODO(board) */
	};
};
```
Unit address must equal `reg`. Address, pull-ups and level shifting are
board facts.

## 5. Minimal example

See `templates/v4l2_sensor_driver.c` (`mysensor_probe`, `of_device_id`,
`module_i2c_driver`). Chip identification pattern: read the ID registers
right after first power-up, fail with `dev_err_probe(..., -ENODEV, ...)` on
mismatch so a wrong address or unpowered chip is obvious in `dmesg`.

## 6. Common pitfalls

- Probing before power: supplies, clock and reset must be up before the
  first transfer.
- Wrong address width/endianness in the register map (8-bit vs 16-bit
  register addresses): reads return plausible garbage.
- 7-bit vs 8-bit address confusion between datasheet and DT.
- Ignoring error returns from every transfer.
- Calling sleeping I2C transfers from atomic context (IRQ handler, spinlock).
- Two drivers (or a userspace `i2c-dev` tool) fighting over one address.

## 7. How to test

`i2cdetect -l` (buses), `i2cdetect -y -r <bus>` (address responds; unsafe on
some devices, read-only probe), `i2cget` for the ID register; on kernels with
`CONFIG_I2C_DEBUG_*` / regmap debugfs, inspect traffic. Keep the chip
unbound while poking from userspace.

## 8. References

- `Documentation/i2c/writing-clients.rst`, `Documentation/driver-api/i2c.rst`,
  `Documentation/i2c/dev-interface.rst` (mainline).
- *Linux Device Drivers 3rd ed.* ch. 14 (device model background); the
  I2C-specific API is better covered by the in-tree documents above.
