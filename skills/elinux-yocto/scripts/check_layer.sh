#!/usr/bin/env bash
# Static checks for a Yocto layer that carries a kernel change (built-in
# sensor driver + overlay) on meta-raspberrypi. Parses recipes only; does NOT
# build, so it proves metadata consistency, not that the image boots.
#
# Run after sourcing oe-init-build-env (bitbake must be on PATH).
#
# Usage: check_layer.sh --layer PATH [--patch NAME] [--cfg NAME]
#                       [--overlay NAME.dtbo] [--machine M] [--compat-check]
#   --layer         layer directory (must already be in bblayers.conf)
#   --patch/--cfg   file names expected in SRC_URI of virtual/kernel
#   --overlay       expected entry in KERNEL_DEVICETREE (overlays/NAME.dtbo)
#   --machine       default raspberrypi0-2w-64
#   --compat-check  also run yocto-check-layer (slow; needs poky scripts)
set -u

layer="" patch="" cfg="" overlay="" machine="raspberrypi0-2w-64" compat=0
while [ $# -gt 0 ]; do
	case "$1" in
	--layer) layer="$2"; shift 2 ;;
	--patch) patch="$2"; shift 2 ;;
	--cfg) cfg="$2"; shift 2 ;;
	--overlay) overlay="$2"; shift 2 ;;
	--machine) machine="$2"; shift 2 ;;
	--compat-check) compat=1; shift ;;
	-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
command -v bitbake >/dev/null || { echo "bitbake not on PATH: source oe-init-build-env first" >&2; exit 2; }
[ -n "$layer" ] || { echo "--layer is required" >&2; exit 2; }

rc=0
ok()   { echo "PASS $*"; }
bad()  { echo "FAIL $*"; rc=1; }

layer_abs="$(cd "$layer" 2>/dev/null && pwd)" || { echo "no such layer: $layer" >&2; exit 2; }

[ -f "$layer_abs/conf/layer.conf" ] && ok "layer.conf present" || bad "missing conf/layer.conf"
grep -q 'LAYERSERIES_COMPAT' "$layer_abs/conf/layer.conf" && ok "LAYERSERIES_COMPAT set" || bad "LAYERSERIES_COMPAT missing"

if bitbake-layers show-layers 2>/dev/null | grep -q "$layer_abs"; then
	ok "layer is in bblayers.conf"
else
	bad "layer not in bblayers.conf (bitbake-layers add-layer $layer_abs)"
fi

if bitbake -p >/tmp/check_layer_parse.log 2>&1; then
	ok "bitbake -p parses all recipes"
else
	tail -20 /tmp/check_layer_parse.log; bad "recipe parse errors"
fi

env_out="$(MACHINE="$machine" BB_ENV_PASSTHROUGH_ADDITIONS=MACHINE bitbake -e virtual/kernel 2>/dev/null)"
[ -n "$env_out" ] || { bad "bitbake -e virtual/kernel produced nothing"; exit 1; }
val() { printf '%s\n' "$env_out" | sed -n "s/^$1=\"\(.*\)\"\$/\1/p" | head -1; }

ok "kernel recipe: $(val PN) $(val LINUX_VERSION), defconfig $(val KBUILD_DEFCONFIG)"

srcuri="$(val SRC_URI)"
[ -z "$patch" ] || { case "$srcuri" in *"$patch"*) ok "SRC_URI has $patch" ;; *) bad "SRC_URI lacks $patch" ;; esac; }
[ -z "$cfg" ]   || { case "$srcuri" in *"$cfg"*)   ok "SRC_URI has $cfg" ;;   *) bad "SRC_URI lacks $cfg" ;; esac; }

if [ -n "$overlay" ]; then
	case "$(val KERNEL_DEVICETREE)" in
	*"overlays/$overlay"*) ok "KERNEL_DEVICETREE ships overlays/$overlay" ;;
	*) bad "overlays/$overlay not in KERNEL_DEVICETREE (set RPI_KERNEL_DEVICETREE_OVERLAYS)" ;;
	esac
fi

if [ "$compat" = 1 ]; then
	if command -v yocto-check-layer >/dev/null; then
		yocto-check-layer "$layer_abs" && ok "yocto-check-layer" || bad "yocto-check-layer"
	else
		echo "SKIP yocto-check-layer not on PATH"
	fi
fi
exit "$rc"
