#!/usr/bin/env bash
# Detect the build system of a source tree. Heuristic: prints a verdict and
# the evidence; the caller must confirm with the user.
#
# Usage: detect_build_system.sh [dir]
# Output (stdout): first line is the verdict, remaining lines are evidence.
# Verdicts: yocto | buildroot | kernel-tree | cmake | make | unknown
# Exit status: 0 if a verdict other than "unknown" was reached, 1 otherwise.
set -euo pipefail

dir="${1:-.}"
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; exit 2; }
cd "$dir"

evidence=()
verdict="unknown"

has() { [ -e "$1" ]; }
found() { evidence+=("$1"); }

# Yocto / OpenEmbedded: layers have conf/layer.conf; build dirs have bblayers.
if has conf/layer.conf || has meta/conf/layer.conf || has poky/oe-init-build-env \
   || has oe-init-build-env || has build/conf/bblayers.conf || has conf/bblayers.conf; then
	verdict="yocto"
	for f in conf/layer.conf meta/conf/layer.conf poky/oe-init-build-env \
	         oe-init-build-env build/conf/bblayers.conf conf/bblayers.conf; do
		has "$f" && found "$f"
	done
elif compgen -G "*.bb" >/dev/null || compgen -G "*.bbappend" >/dev/null \
     || compgen -G "recipes-*/*/*.bb*" >/dev/null; then
	verdict="yocto"
	found "recipe files (*.bb / *.bbappend)"
fi

# Buildroot: top-level tree or a BR2_EXTERNAL tree.
if [ "$verdict" = "unknown" ]; then
	if has Config.in && has Makefile && has package/Config.in && has support/; then
		verdict="buildroot"; found "Config.in + package/Config.in + support/"
	elif has external.desc || has external.mk; then
		verdict="buildroot"; found "BR2_EXTERNAL files (external.desc / external.mk)"
	elif compgen -G "configs/*_defconfig" >/dev/null && compgen -G "package/*/*.mk" >/dev/null; then
		verdict="buildroot"; found "configs/*_defconfig + package/*/*.mk"
	fi
fi

# Linux kernel source tree.
if [ "$verdict" = "unknown" ] && has Kbuild && has Kconfig && has arch && has drivers \
   && has scripts/kconfig; then
	verdict="kernel-tree"; found "Kbuild + Kconfig + arch/ + drivers/ + scripts/kconfig"
fi

# Out-of-tree kernel module: Kbuild/Makefile with obj-m.
if [ "$verdict" = "unknown" ] && grep -qsE '^\s*obj-m\b' Kbuild Makefile 2>/dev/null; then
	verdict="make"; found "obj-m in Kbuild/Makefile (out-of-tree kernel module)"
fi

if [ "$verdict" = "unknown" ] && has CMakeLists.txt; then
	verdict="cmake"; found "CMakeLists.txt"
fi
if [ "$verdict" = "unknown" ] && { has Makefile || has makefile || has GNUmakefile; }; then
	verdict="make"; found "Makefile"
fi

echo "$verdict"
for e in "${evidence[@]:-}"; do
	[ -n "$e" ] && echo "  evidence: $e"
done
[ "$verdict" != "unknown" ]
