#!/usr/bin/env bash
# Lint a device tree source with dtc; optionally apply an overlay to a base DTB.
#
# Usage: lint_dts.sh FILE.dts [--base BASE.dtb] [--include DIR]... [--strict]
#
#   FILE.dts      DTS or overlay source (an overlay has "/plugin/;")
#   --base        base DTB (compiled with dtc -@) to apply the overlay onto
#                 with fdtoverlay; proves every label resolves
#   --include     extra include dirs for cpp (#include "x.dtsi" / dt-bindings)
#   --strict      treat dtc warnings as failures
#
# Limits: dtc checks syntax and generic DT rules only. It does not validate
# against binding schemas (needs dt-schema: make dt_binding_check) and does
# not know Raspberry Pi firmware extensions such as __overrides__.
set -euo pipefail

src="" base="" strict=0
incs=()
while [ $# -gt 0 ]; do
	case "$1" in
	--base) base="$2"; shift 2 ;;
	--include) incs+=("-I" "$2"); shift 2 ;;
	--strict) strict=1; shift ;;
	-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
	-*) echo "unknown option: $1" >&2; exit 2 ;;
	*) src="$1"; shift ;;
	esac
done
if [ -z "$src" ] || [ ! -f "$src" ]; then
	echo "usage: $0 FILE.dts [--base BASE.dtb]" >&2; exit 2
fi
command -v dtc >/dev/null || { echo "dtc not found (apt install device-tree-compiler)" >&2; exit 3; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pre="$tmp/pre.dts"
cpp -nostdinc -undef -x assembler-with-cpp -D__DTS__ "${incs[@]}" "$src" -o "$pre" 2>"$tmp/cpp.err" \
	|| { cat "$tmp/cpp.err" >&2; echo "FAIL: preprocessing"; exit 1; }

flags=(-I dts -O dtb -@)
if grep -q '/plugin/;' "$pre"; then kind=overlay; else kind=tree; fi

dtc "${flags[@]}" -o "$tmp/out.dtb" "$pre" 2>"$tmp/dtc.err" || {
	cat "$tmp/dtc.err" >&2; echo "FAIL: dtc ($kind)"; exit 1; }
if [ -s "$tmp/dtc.err" ]; then
	cat "$tmp/dtc.err" >&2
	[ "$strict" = 1 ] && { echo "FAIL: warnings with --strict"; exit 1; }
fi
echo "OK: dtc compiled $src as $kind"

if [ -n "$base" ]; then
	[ "$kind" = overlay ] || { echo "--base only makes sense for an overlay" >&2; exit 2; }
	command -v fdtoverlay >/dev/null || { echo "fdtoverlay not found" >&2; exit 3; }
	fdtoverlay -i "$base" -o "$tmp/merged.dtb" "$tmp/out.dtb" 2>"$tmp/fdt.err" || {
		cat "$tmp/fdt.err" >&2
		echo "FAIL: overlay does not apply to $base (unresolved label, missing target," \
		     "or a label on an __overlay__ node)"; exit 1; }
	echo "OK: overlay applied to $base"
fi
