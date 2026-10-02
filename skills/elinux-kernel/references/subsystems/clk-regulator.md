# Clock and regulator consumers

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use in any driver that needs an external clock (sensor XCLK, codec MCLK) or
power rails. Not for writing clock/regulator *providers* (clk drivers,
PMICs), which are separate chapters.

## 2. Conceptual model

- **Consumer** code asks by *name from DT* (`clocks`/`clock-names`,
  `<name>-supply`). It never knows the provider.
- Clock: `get` (once, devm), `prepare_enable` before use, rate checked or
  set by the consumer only if the provider allows it, `disable_unprepare`
  after.
- Regulator: `bulk_get` the set of supplies, `bulk_enable` in order,
  `bulk_disable` in reverse.
- On Raspberry Pi camera connectors both are *fixed* providers defined in
  the base DT: `cam1_clk` (`fixed-clock`, rate set by the overlay) and
  `cam1_reg` (`regulator-fixed`, enable GPIO set in the board DT). A
  sensor's rails that are not switchable point at the dummy regulator
  `cam_dummy_reg`. Whether your module needs more than that is a schematic
  question.

## 3. API and kernel versions

| API (rpi-6.6.y) | Use |
|---|---|
| `devm_clk_get()`, `devm_clk_get_optional()` | acquire clock; returns `-EPROBE_DEFER` if provider absent |
| `clk_prepare_enable()` / `clk_disable_unprepare()` | may sleep |
| `clk_get_rate()` | validate the rate the DT gave you |
| `devm_regulator_bulk_get()` | `struct regulator_bulk_data` with `.supply` names |
| `regulator_bulk_enable()` / `_disable()` | enable order = array order |

`clk_get_rate()` on a `fixed-clock` returns the DT `clock-frequency`;
validate it and fail probe with a clear message rather than programming PLLs
for a rate you did not get.

## 4. Device Tree binding

```
sensor@<addr> {
	clocks = <&cam1_clk>;              /* Raspberry Pi label */
	avdd-supply = <&cam1_reg>;         /* TODO(board): which rails */
	dovdd-supply = <&cam_dummy_reg>;   /* TODO(board) */
};
&cam1_clk { clock-frequency = <...>; status = "okay"; };  /* TODO(datasheet) */
&cam1_reg { startup-delay-us = <...>; };                  /* TODO(datasheet) */
```
Supply property names must equal `supply` strings in the driver
(`devm_regulator_bulk_get` looks for `<supply>-supply`).

## 5. Minimal example

`templates/v4l2_sensor_driver.c`: `mysensor_power_on()/power_off()` and the
bulk-regulator setup in `mysensor_probe()`.

## 6. Common pitfalls

- `-EPROBE_DEFER` swallowed or turned into a hard failure (use
  `dev_err_probe`).
- Disabling a clock/regulator that was never enabled, or the reverse order
  on teardown (leaks a reference, rails stay on).
- Enabling in `probe` and again in runtime-PM resume without balancing.
- Missing supply in DT: on boards that declare full regulator constraints
  the core substitutes a dummy regulator for an undeclared supply instead
  of failing, so the driver "works" in software while the rail is never
  switched. Check `regulator_summary` rather than trusting a clean probe.
- Reading `clk_get_rate()` before the provider is enabled when the
  provider reports 0 until enabled.

## 7. How to test

`/sys/kernel/debug/clk/clk_summary` (enable count, rate),
`/sys/kernel/debug/regulator/regulator_summary` (use count, state) before
and after streaming; measure the rail/clock with a scope when bring-up
fails.

## 8. References

- `Documentation/driver-api/clk.rst`, `Documentation/power/regulator/consumer.rst`,
  `Documentation/devicetree/bindings/clock/clock-bindings.txt` (mainline).
- rpi-6.6.y `arch/arm/boot/dts/broadcom/bcm270x.dtsi` (labels above).
