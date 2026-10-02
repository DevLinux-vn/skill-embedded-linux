#!/usr/bin/env bash
# Instantiate templates/v4l2_sensor_driver.c for a concrete sensor and, when
# --kernel-dir is given, wire it into a Raspberry Pi kernel tree as a
# built-in/module driver (drivers/media/i2c + Kconfig + Makefile).
#
# Verified against: raspberrypi/linux rpi-6.6.y (6.6.78).
#
# Usage:
#   scaffold_sensor_driver.sh --name NAME --vendor PREFIX [--out DIR]
#                             [--kernel-dir DIR] [--no-overlay]
#
#   --name        lowercase driver/sensor name, e.g. "mycam" -> mycam.c,
#                 CONFIG_VIDEO_MYCAM, compatible "<vendor>,mycam"
#   --vendor      DT vendor prefix (must exist in vendor-prefixes.yaml)
#   --out         output dir when not touching a kernel tree (default: ./out)
#   --kernel-dir  kernel source tree: driver, Kconfig, Makefile, overlay
#                 and a .config fragment are added there
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tpl_dir="$here/../templates"
name="" vendor="" out="./out" kdir="" overlay=1

while [ $# -gt 0 ]; do
	case "$1" in
	--name) name="$2"; shift 2 ;;
	--vendor) vendor="$2"; shift 2 ;;
	--out) out="$2"; shift 2 ;;
	--kernel-dir) kdir="$2"; shift 2 ;;
	--no-overlay) overlay=0; shift ;;
	-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

[[ "$name" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "--name must match [a-z][a-z0-9_]*" >&2; exit 2; }
[[ "$vendor" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "--vendor must match [a-z][a-z0-9-]*" >&2; exit 2; }
upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"

instantiate() { # src dst
	sed -e "s/mysensor/${name}/g" -e "s/MYSENSOR/${upper}/g" \
	    -e "s/vendor,${name}/${vendor},${name}/g" "$1" > "$2"
}

if [ -z "$kdir" ]; then
	mkdir -p "$out"
	instantiate "$tpl_dir/v4l2_sensor_driver.c" "$out/${name}.c"
	[ "$overlay" = 1 ] && instantiate "$tpl_dir/overlay.dts" "$out/${name}-overlay.dts"
	echo "wrote $out/${name}.c (fill every TODO(datasheet)/TODO(board))"
	exit 0
fi

media="$kdir/drivers/media/i2c"
if [ ! -f "$media/Kconfig" ] || [ ! -f "$media/Makefile" ]; then
	echo "not a kernel tree: $kdir" >&2; exit 1
fi
grep -q "^config VIDEO_${upper}\$" "$media/Kconfig" && {
	echo "CONFIG_VIDEO_${upper} already exists in $media/Kconfig" >&2; exit 1; }
[ -e "$media/${name}.c" ] && {
	echo "$media/${name}.c already exists: an upstream/vendor driver may already" \
	     "cover this sensor, check before duplicating" >&2; exit 1; }

instantiate "$tpl_dir/v4l2_sensor_driver.c" "$media/${name}.c"

python3 - "$media" "$name" "$upper" <<'PY'
import sys, pathlib
media, name, upper = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
kc = media / "Kconfig"
text = kc.read_text()
anchor = "config VIDEO_IMX219\n"
entry = f"""config VIDEO_{upper}
	tristate "{upper} sensor support"
	select V4L2_CCI_I2C
	help
	  Video4Linux2 sensor driver for the {upper} camera (scaffolded from
	  the elinux-kernel template; review before use).

	  To compile this driver as a module, choose M here: the
	  module will be called {name}.

"""
if anchor not in text:
    sys.exit("anchor 'config VIDEO_IMX219' not found: edit Kconfig by hand")
kc.write_text(text.replace(anchor, entry + anchor, 1))
mk = media / "Makefile"
line = f"obj-$(CONFIG_VIDEO_{upper}) += {name}.o\n"
mt = mk.read_text()
a = "obj-$(CONFIG_VIDEO_IMX219) += imx219.o\n"
if a not in mt:
    sys.exit("anchor imx219 not found in Makefile: edit by hand")
mk.write_text(mt.replace(a, a + line, 1))
PY

if [ "$overlay" = 1 ]; then
	ov="$kdir/arch/arm/boot/dts/overlays"
	instantiate "$tpl_dir/overlay.dts" "$ov/${name}-overlay.dts"
	python3 - "$ov/Makefile" "$name" <<'PY'
import sys, re, pathlib
mk, name = pathlib.Path(sys.argv[1]), sys.argv[2]
t = mk.read_text()
entry = f"\t{name}.dtbo \\\n"
if entry in t:
    sys.exit(0)
m = re.search(r"^\tov5647\.dtbo \\\n", t, re.M)
if not m:
    sys.exit("anchor ov5647.dtbo not found in overlays/Makefile: edit by hand")
mk.write_text(t[:m.start()] + entry + t[m.start():])
PY
fi

cat > "$kdir/${name}.config" <<EOF
# Config fragment for ${name}. Built-in (=y) requires its dependencies to be
# built-in too: check 'make olddefconfig' did not demote it to =m.
CONFIG_VIDEO_${upper}=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_VIDEO_DEV=y
CONFIG_V4L2_FWNODE=y
CONFIG_V4L2_CCI_I2C=y
EOF

echo "scaffolded ${name} in $kdir"
echo "next: ARCH=arm64 scripts/kconfig/merge_config.sh .config ${name}.config && make olddefconfig"
