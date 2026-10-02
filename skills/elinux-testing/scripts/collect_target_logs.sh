#!/usr/bin/env bash
# Collect a diagnostic bundle from a running embedded Linux target.
# Run ON the target (or: ssh target 'sh -s' < collect_target_logs.sh).
# Read-only: it does not change device state. Output: tarball path on stdout.
#
# Usage: collect_target_logs.sh [outdir]
set -u

out="${1:-/tmp}"
ts="$(date +%Y%m%d-%H%M%S)"
dir="$out/target-logs-$ts"
mkdir -p "$dir"

run() { # name cmd...
	local name="$1"; shift
	{ echo "# $*"; "$@" 2>&1; } > "$dir/$name.txt" || true
}
cat_file() { # name path
	if [ -r "$2" ]; then { echo "# $2"; cat "$2"; } > "$dir/$1.txt" 2>&1; fi
}

run uname uname -a
cat_file model /proc/device-tree/model
cat_file cpuinfo /proc/cpuinfo
cat_file meminfo /proc/meminfo
cat_file cmdline /proc/cmdline
cat_file os-release /etc/os-release
run dmesg dmesg
command -v journalctl >/dev/null && run journal-kernel journalctl -k -b --no-pager
run lsmod lsmod
cat_file deferred /sys/kernel/debug/devices_deferred
cat_file clk_summary /sys/kernel/debug/clk/clk_summary
cat_file regulator_summary /sys/kernel/debug/regulator/regulator_summary
cat_file gpio_debug /sys/kernel/debug/gpio
run i2c-buses sh -c 'command -v i2cdetect >/dev/null && i2cdetect -l'
# shellcheck disable=SC2016  # expansion must happen in the inner shell
run media-devices sh -c 'for m in /dev/media*; do [ -e "$m" ] && { echo "== $m"; media-ctl -d "$m" -p; }; done'
run v4l2-devices sh -c 'command -v v4l2-ctl >/dev/null && v4l2-ctl --list-devices'
run gpioinfo sh -c 'command -v gpioinfo >/dev/null && gpioinfo'
run config-gz sh -c '[ -r /proc/config.gz ] && zcat /proc/config.gz'
if [ -r /proc/device-tree ] && command -v dtc >/dev/null; then
	run live-dts dtc -I fs -O dts /proc/device-tree
fi
for f in /boot/config.txt /boot/firmware/config.txt; do
	[ -r "$f" ] && cp "$f" "$dir/$(echo "$f" | tr / _).txt"
done

tar -C "$out" -czf "$dir.tar.gz" "target-logs-$ts" && echo "$dir.tar.gz"
