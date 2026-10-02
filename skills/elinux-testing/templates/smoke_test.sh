#!/usr/bin/env bash
# Camera/media smoke test, run on the target. Discovers devices instead of
# assuming numbers. Exits non-zero on the first failed level.
#
# Usage: smoke_test.sh --driver NAME [--frames N] [--video /dev/videoN]
#   --driver  I2C driver name (the sysfs name under /sys/bus/i2c/drivers/)
#   --frames  frames to capture (default 10)
#   --video   capture node; default: first node that streams
#
# Levels: 1 driver bound, 2 no errors in dmesg, 3 media graph has the sensor,
#         4 frames captured. Each level prints PASS/FAIL with evidence.
set -u

driver="" frames=10 video=""
while [ $# -gt 0 ]; do
	case "$1" in
	--driver) driver="$2"; shift 2 ;;
	--frames) frames="$2"; shift 2 ;;
	--video) video="$2"; shift 2 ;;
	-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
[ -n "$driver" ] || { echo "--driver is required" >&2; exit 2; }

fail() { echo "FAIL [$1] $2"; exit 1; }
pass() { echo "PASS [$1] $2"; }

# 1. driver bound to an I2C device (built-in or module)
bound=""
for d in "/sys/bus/i2c/drivers/$driver"/[0-9]*-[0-9a-f]*; do
	[ -e "$d" ] && { bound="${d##*/}"; break; }
done
[ -n "$bound" ] || fail 1 "no I2C device bound to '$driver' (overlay applied? compatible matches?)"
pass 1 "bound: $bound"

# 2. kernel log: no errors mentioning the driver or the camera path
errs="$(dmesg | grep -i -E "$driver|unicam|csi" | grep -i -E 'error|fail|timeout|oops|BUG|warn' || true)"
[ -z "$errs" ] || { echo "$errs"; fail 2 "errors in dmesg"; }
pass 2 "dmesg clean for $driver/unicam/csi"

# 3. media graph contains an entity from this driver
if command -v media-ctl >/dev/null; then
	found=""
	for m in /dev/media*; do
		[ -e "$m" ] || continue
		if media-ctl -d "$m" -p 2>/dev/null | grep -qi "$driver"; then found="$m"; break; fi
	done
	[ -n "$found" ] || fail 3 "no media device lists an entity matching '$driver'"
	pass 3 "media graph: $found"
else
	echo "SKIP [3] media-ctl not installed"
fi

# 4. capture frames
command -v v4l2-ctl >/dev/null || { echo "SKIP [4] v4l2-ctl not installed"; exit 0; }
cands="$video"
[ -n "$cands" ] || cands="$(ls /dev/video* 2>/dev/null)"
for v in $cands; do
	if v4l2-ctl -d "$v" --stream-mmap --stream-count="$frames" --stream-to=/dev/null >/tmp/smoke_stream.log 2>&1; then
		pass 4 "captured $frames frames from $v"
		exit 0
	fi
done
cat /tmp/smoke_stream.log 2>/dev/null
fail 4 "no video node streamed (check media-ctl format setup and dmesg)"
