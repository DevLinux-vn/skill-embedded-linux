# GPIO descriptors and pinctrl

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use when a driver needs to drive or read a GPIO (reset, power-down, enable,
interrupt line) or when pin functions (muxing) must be selected. Not for
userspace GPIO access (`elinux-userspace/references/hardware-access/gpio-libgpiod.md`),
and not for writing a GPIO or pinctrl *controller* driver.

## 2. Conceptual model

- **Descriptor API** (`gpiod_*`): the driver asks for a GPIO by *function
  name* (`"reset"`), the DT supplies `reset-gpios = <&gpio N FLAGS>`. Polarity
  (`GPIO_ACTIVE_LOW/HIGH`) lives in DT; driver code uses **logical** values
  (1 = asserted).
- **Never** use the legacy integer API (`gpio_request`, global numbers) in
  new code; global GPIO numbers are not stable.
- **pinctrl** assigns a pin's function (GPIO, I2C, CSI clock...) and
  pull/drive. Drivers usually do nothing: the DT `pinctrl-0` / `pinctrl-names`
  on the device node make the core apply the `default` state before probe.
- On Raspberry Pi the camera connector's control lines are wired by the
  board DT (for example the camera power regulator's enable GPIO lives on
  the `cam1_reg` node in the board file). What GPIO that is, is a board
  fact: read the board DT and the camera-module schematic.

## 3. API and kernel versions

| API (rpi-6.6.y) | Use |
|---|---|
| `devm_gpiod_get(dev, "con_id", GPIOD_OUT_HIGH)` | required GPIO, initial *logical* state |
| `devm_gpiod_get_optional()` | returns NULL if absent; all `gpiod_set_value*()` accept NULL |
| `gpiod_set_value_cansleep()` | use unless you know the controller is memory-mapped and you are in atomic context |
| `gpiod_to_irq()` | interrupt from a GPIO input |
| `<linux/gpio/consumer.h>` | header for consumers |

## 4. Device Tree binding

```
reset-gpios = <&gpio 0 GPIO_ACTIVE_LOW>;   /* TODO(board): controller, line, polarity */
pinctrl-names = "default";
pinctrl-0 = <&some_pins>;                   /* only if the pins need muxing */
```
`con_id` `"reset"` maps to property `reset-gpios`. Include
`<dt-bindings/gpio/gpio.h>` for the flag names.

## 5. Minimal example

`templates/v4l2_sensor_driver.c`: `devm_gpiod_get_optional(dev, "reset",
GPIOD_OUT_HIGH)` at probe (starts asserted = in reset), released with
`gpiod_set_value_cansleep(s->reset, 0)` in `power_on`, re-asserted in
`power_off`. The inversion for active-low wiring is handled by the DT flag.

## 6. Common pitfalls

- Hard-coding polarity in the driver, then setting the opposite flag in DT.
- Initial state wrong: `GPIOD_OUT_LOW` with an active-low reset deasserts
  the reset at probe, before power is stable.
- Using `gpiod_set_value()` (non-sleeping) on an I2C/SPI-expander GPIO.
- Assuming the optional GPIO exists: the board may route reset through a
  regulator instead (then there is no GPIO node at all).
- Requesting a GPIO already claimed by the firmware/another driver
  (`-EBUSY`), or exported through the deprecated sysfs interface.
- Using sysfs GPIO numbers from a different kernel/board in the DT.

## 7. How to test

`gpioinfo` / `gpiomon` (libgpiod) to see line names, consumers and levels
(`elinux-testing/references/on-target-tools.md`);
`/sys/kernel/debug/gpio` and `/sys/kernel/debug/pinctrl/*/pinmux-pins` for
ownership and mux state; scope the line during power-up.

## 8. References

- `Documentation/driver-api/gpio/consumer.rst`,
  `Documentation/driver-api/gpio/board.rst`,
  `Documentation/driver-api/pin-control.rst`,
  `Documentation/devicetree/bindings/gpio/gpio.txt` (mainline).
