#!/usr/bin/env bash
#
# extract_ddr_params.sh — dump the real DDR parameter values Rockchip ships
# inside an RK3576 DDR blob, using Jonas Karlman's open-source ddrbin_tool.py
# (github.com/Kwiboo/rkbin-2).
#
# This reads only the *parameter block* (frequencies, ODT/drive ohms, VREF,
# slew, CA/DQ skew, CA/byte/DQ swap, address-hash masks) — it does NOT
# disassemble or extract init/training code. The values are board-tuning data,
# usable as authoritative starting points for a from-source driver.
#
# Caveat: the rkbin-2 fork has per-chip config blocks only up to rk3588/rv1126b;
# rk3576 is recognised but may not have a dedicated block. If the rk3576 run
# fails, this script retries with the rk3588 layout as a proxy (the v7 struct
# layout is shared). Treat proxied output as "to be verified against the TRM".
#
# Usage:
#   ./extract_ddr_params.sh <blob.bin> [max_adc_groups] [out_dir]
#
# Example:
#   ./extract_ddr_params.sh rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin 12 ./out
#
set -euo pipefail

BLOB="${1:-}"
MAX_GROUPS="${2:-1}"
OUT_DIR="${3:-./extracted}"
TOOL_REPO="https://github.com/Kwiboo/rkbin-2.git"
TOOL_DIR="${DDRBIN_TOOL_DIR:-./rkbin-2}"
TYPES=("LPDDR5" "LPDDR4" "LPDDR4X")
CHIPS=("rk3576" "rk3588")   # primary, then proxy fallback

die() { echo "error: $*" >&2; exit 1; }

[ -n "$BLOB" ] || die "no blob given. Usage: $0 <blob.bin> [max_adc_groups] [out_dir]"
[ -f "$BLOB" ] || die "blob not found: $BLOB"
case "$MAX_GROUPS" in (*[!0-9]*|'') die "max_adc_groups must be an integer";; esac

# Locate or fetch the tool.
TOOL=""
if [ -f "$TOOL_DIR/tools/ddrbin_tool.py" ]; then
	TOOL="$TOOL_DIR/tools/ddrbin_tool.py"
elif command -v ddrbin_tool.py >/dev/null 2>&1; then
	TOOL="$(command -v ddrbin_tool.py)"
else
	echo "ddrbin_tool.py not found; cloning $TOOL_REPO -> $TOOL_DIR" >&2
	command -v git >/dev/null 2>&1 || die "git required to fetch the tool"
	git clone --depth 1 "$TOOL_REPO" "$TOOL_DIR"
	TOOL="$TOOL_DIR/tools/ddrbin_tool.py"
fi
[ -f "$TOOL" ] || die "ddrbin_tool.py still not found at $TOOL"
command -v python3 >/dev/null 2>&1 || die "python3 required"

mkdir -p "$OUT_DIR"
echo "tool : $TOOL"
echo "blob : $BLOB"
echo "out  : $OUT_DIR"
echo "groups: 1..$MAX_GROUPS, types: ${TYPES[*]}"
echo

# Try one extraction; echo the file on success, return non-zero on failure.
try_dump() {
	local chip="$1" type="$2" group="$3" out="$4"
	local args=("$chip" -g "$out" "$BLOB" "$type")
	if [ "$group" -gt 0 ]; then
		args+=("adc_value_to_ddr_config=$group")
	fi
	python3 "$TOOL" "${args[@]}" >/dev/null 2>&1
}

ok=0 fail=0
for type in "${TYPES[@]}"; do
	for g in $(seq 1 "$MAX_GROUPS"); do
		out="$OUT_DIR/gen_${type,,}_group${g}.txt"
		used_chip=""
		for chip in "${CHIPS[@]}"; do
			# Single-group blobs ignore the group arg; pass 0 when MAX_GROUPS==1.
			grp_arg=$([ "$MAX_GROUPS" -eq 1 ] && echo 0 || echo "$g")
			if try_dump "$chip" "$type" "$grp_arg" "$out"; then
				used_chip="$chip"; break
			fi
		done
		if [ -n "$used_chip" ] && [ -s "$out" ]; then
			tag=$([ "$used_chip" = rk3576 ] && echo "" || echo "  [PROXY:$used_chip — verify vs TRM]")
			echo "  ok   $out${tag}"
			ok=$((ok+1))
		else
			rm -f "$out"
			fail=$((fail+1))
		fi
	done
done

echo
echo "done: $ok extracted, $fail skipped (type/group not present in this blob)."
[ "$ok" -gt 0 ] || die "nothing extracted — check the blob path, type, and group count."
echo "next: python3 ddrparam_to_inc.py $OUT_DIR/gen_lpddr5_group1.txt > rk3576-lpddr5-extracted.inc.txt"
