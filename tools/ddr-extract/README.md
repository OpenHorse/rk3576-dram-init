# DDR parameter extraction workflow

Pull the **real DDR parameter values** Rockchip ships inside an RK3576 DDR blob,
and map them onto the from-source driver's structures. This gives authoritative
starting numbers (frequencies, ODT/drive ohms, VREF, slew, CA/DQ skew, board
swizzle, address masks) for the placeholder timing tables and the PHY settings
the driver currently leaves at reset defaults.

## What this does and does not do

- **Does:** read the blob's *parameter block* (the inputs the blob consumes)
  via Jonas Karlman's open-source `ddrbin_tool.py` (`Kwiboo/rkbin-2`), and
  bucket the populated values by which driver register/struct they feed.
- **Does not:** disassemble or extract the blob's init/training **code**. The
  register-write sequence and PHY training algorithm are not touched and are
  not derivable from this — they remain TRM + hardware work. The numbers this
  pulls are board-tuning **data**, not code.

This keeps us on the right side of provenance for an upstream-targeted driver:
we use documented parameter *values*, not reverse-engineered firmware.

## Prerequisites

- `python3`, `git`, `bash`.
- An RK3576 DDR blob from `rockchip-linux/rkbin`, e.g.
  `bin/rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin`. Download it yourself;
  it is not redistributed here.

## Usage

There are two equivalent extractors — `extract_ddr_params.ps1` (Windows
PowerShell) and `extract_ddr_params.sh` (bash). The mapper `ddrparam_to_inc.py`
is the same on both.

### PowerShell (Windows)

```powershell
# 1. Extract. Single-config blob:
.\extract_ddr_params.ps1 -Blob rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin
#    Multi-config (ADC-strap) blob with N groups (e.g. 12):
.\extract_ddr_params.ps1 -Blob rk3576_ddr_..._v1.13.bin -MaxGroups 12 -OutDir .\extracted

# 2. Map a dump onto the driver structures (repeat per type/group):
python ddrparam_to_inc.py .\extracted\gen_lpddr5_group1.txt > rk3576-lpddr5-extracted.txt
```

If scripts are blocked, run once with:
`powershell -ExecutionPolicy Bypass -File .\extract_ddr_params.ps1 -Blob ...`

### bash (Linux/macOS/WSL)

```bash
# 1. Extract. Args: <blob> [max_adc_groups] [out_dir]
./extract_ddr_params.sh rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin
./extract_ddr_params.sh rk3576_ddr_..._v1.13.bin 12 ./extracted

# 2. Map a dump:
python3 ddrparam_to_inc.py ./extracted/gen_lpddr5_group1.txt > rk3576-lpddr5-extracted.txt
```

Both extractors fetch `Kwiboo/rkbin-2` into `./rkbin-2` on first run (override
with the `DDRBIN_TOOL_DIR` environment variable).

## The rk3576 / rk3588 proxy caveat

The `rkbin-2` fork's per-chip parameter blocks currently cover up to
`rk3588` / `rv1126b`; `rk3576` is recognised but may lack a dedicated block.
If an `rk3576` run fails, the extractor retries with the **`rk3588` layout**
as a proxy (the v7 parameter struct is shared across the combo-PHY parts) and
tags those outputs `[PROXY:rk3588 — verify vs TRM]`. Treat proxied field
offsets as unverified until checked against the RK3576 TRM.

## Reading the output

`ddrparam_to_inc.py` prints two clearly separated classes:

- `[BLOB]` — real values present in the blob, usable now: operating
  frequencies (map ascending onto `DDRCTL_FREQ_BASE(0..3)`, final = boot
  point), PHY ODT/drive/VREF/slew, CA/DQ/CK skew, CA/byte/DQ swap, address
  masks