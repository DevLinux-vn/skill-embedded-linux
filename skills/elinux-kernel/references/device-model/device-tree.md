# Device tree for driver authors

Status: complete
Verified: kernel=rpi-6.6.y@6.6.78 (raspberrypi/linux bba53a1); yocto=scarthgap (meta-raspberrypi, linux-raspberrypi 6.6.63); buildroot=n/a

## 1. When to use / not to use

Use when a driver reads properties from DT or when you add/modify nodes. Not
a general DT tutorial (see `Documentation/devicetree/usage-model.rst`), and
not the place for overlay mechanics (`overlays.md`).

## 2. Conceptual model

- DT describes **hardware that cannot be probed**: addresses, wiring, clocks,
  supplies, interrupts, graph links. It is an ABI between firmware/bootloader
  and kernel, versioned by *bindings*, not by the driver.
- A node binds to a driver by `compatible` (most specific first).
- Phandles (`<&label>`) reference other nodes; **labels are source-level**
  and only exist at runtime if the DTB was compiled with `-@` (symbols).
  Raspberry Pi base DTs are built that way; overlays rely on it.
- Graph (camera, display): `port` / `endpoint` with `remote-endpoint`
  both ways; properties like `data-lanes`, `link-frequencies` described in
  `video-interfaces.yaml`.
- The kernel reads DT through `of_*` / `fwnode_*` / `device_property_*`
  APIs. Prefer the firmware-agnostic `device_property_*`/`fwnode` ones in
  new drivers.

## 3. API and kernel versions

| API | Note |
|---|---|
| `of_device_id` + `MODULE_DEVICE_TABLE(of, ...)` | match table |
| `device_property_read_u32()`, `fwnode_graph_get_next_endpoint()` | property and graph access |
| `v4l2_fwnode_endpoint_alloc_parse()` / `_free()` | camera endpoint parsing |
| `of_property_read_*` | still fine, OF-specific |

Binding schemas (YAML, `dt-schema`) are the contract for upstream; the
Raspberry Pi tree keeps some bindings in legacy `.txt` (Unicam). Do not
claim a binding is "validated" unless `make dt_binding_check` actually ran.

## 4. Device Tree binding

Write bindings for new `compatible` strings. Skeleton:
`templates/binding.yaml`. Rules: node/property names from
`Documentation/devicetree/bindings/writing-bindings.rst`; vendor prefix must
exist in `vendor-prefixes.yaml`; document every property the driver reads,
including supplies and graph.

## 5. Minimal example

Sensor node, graph, and base-DT labels: `templates/overlay.dts`. Inspect the
live tree on target:

```sh
dtc -I fs -O dts /proc/device-tree > live.dts      # whole tree
ls /proc/device-tree/soc/i2c0mux/                  # an overlay-added child
hexdump -C /proc/device-tree/<path>/compatible
```

## 6. Common pitfalls

- Unit address != `reg` (dtc warns; tools and humans get confused).
- `compatible` in DT differs from the driver's `of_device_id` by a typo:
  driver never probes, no error anywhere. Check
  `/sys/bus/i2c/devices/*/of_node` and `driver` symlinks.
- Missing `#address-cells`/`#size-cells` in the parent of a new child.
- Supply/clock property names that do not match what the driver requests.
- Editing the DTB by hand; keep DTS in the tree and rebuild.
- Properties silently ignored because the *binding changed* between kernel
  versions; read the target kernel's binding, not mainline's latest.
- Referencing a label that is not in `__symbols__` of the base DTB: overlay
  apply fails with an unresolved-symbol error.

## 7. How to test

`skills/elinux-kernel/scripts/lint_dts.sh <file>` (dtc warnings); for an
overlay add `--base <base.dtb>` to apply it with `fdtoverlay` and confirm the
node lands where expected. Binding schema: `make dt_binding_check
DT_SCHEMA_FILES=<yaml>` in a kernel tree with `dtschema` installed
(not run in this repo's validation).

## 8. References

- `Documentation/devicetree/usage-model.rst`,
  `Documentation/devicetree/bindings/writing-bindings.rst`,
  `Documentation/devicetree/bindings/writing-schema.rst`,
  `Documentation/devicetree/bindings/media/video-interfaces.yaml`.
- devicetree.org specification (online).
- *Linux Device Drivers 3rd ed.* ch. 14 for the device-model background
  (DT is newer than the book; use in-tree documents for DT itself).
