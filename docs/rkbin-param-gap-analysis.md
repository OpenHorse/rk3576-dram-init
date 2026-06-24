# rkbin `ddrbin_param` → RK3576 register gap analysis

Maps the configuration surface exposed by Rockchip's `rkbin` DDR tool
(`tools/ddrbin_param.txt` + `ddrbin_tool_user_guide.txt`) onto the RK3576
DDRCTL/DDRPHY registers our from-source driver programs, and flags every
parameter group the current driver still leaves at TRM **reset defaults**.

## Why this is a legitimate reference

`ddrbin_param.txt` and the tool user guide describe only the **inputs** the
proprietary DDR blob consumes — parameter names, units, legal value sets, and
ordering rules. They contain no init/training code. They are therefore safe to
read and cite for a clean, upstream-targeted driver. The blob itself
(`rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin`) is proprietary; its register
write sequence and PHY training algorithm are **not** derived here and must
come from the TRM and hardware bring-up.

## Real operating points (retarget the timing tables)

The shipped blob name pins Rockchip's actual operating frequencies:

| Type   | CK (final/f0) | Data rate | Our placeholder `.inc` |
|--------|---------------|-----------|------------------------|
| LPDDR4 | 2112 MHz      | 4224 MT/s | 1560 MHz (too low)     |
| LPDDR5 | 2736 MHz      | 5472 MT/s | 2133 MHz (too low)     |

Action: retarget `sdram-rk3576-lpddr4-*.inc` and `sdram-rk3576-lpddr5-*.inc`
to 2112 / 2736 MHz once real JEDEC/datasheet-derived timings are computed.
RK3576 sits in the RK3588 capability class (combo PHY, LP4 ≤ ~2133 MHz,
LP5 ≤ ~2750 MHz), so RK3588 legal value sets below apply.

## FSP (frequency set point) scheme

The blob initializes DRAM through an **ordered** set of frequency points and
boots at the final one:

```
lp5_f1_freq_mhz < lp5_f2_freq_mhz < lp5_f3_freq_mhz < ... < lp5_freq (= f0, final/boot)
```

`f1` is the lowest, the final `lp*_freq` (== `f0`) is the highest and the boot
frequency; `boot_fsp` selects which point boots (RK3588 style). This maps to
our four per-frequency banks `DDRCTL_FREQ_BASE(0..3)` /
`struct rk3576_ddrctl_freq_params freq[RK3576_DDRCTL_NFREQS]`.

**Gap:** the placeholder `.inc` files use **identical** values for all four
banks (`[0..3] = LP*_FREQ_TMG`). Real tables must differentiate each bank by
its operating point and order them low→high, with the boot/target point in the
final bank. The kernel DMC DT freq table must match these points.

## Parameter group → register map

| `ddrbin_param` group | RK3576 register / struct (header) | Driver status | Action |
|----------------------|-----------------------------------|---------------|--------|
| `lp*_freq`, `lp*_f1..f5_freq_mhz` | per-FREQ banks `DDRCTL_FREQ_BASE(n)`; `DDRCRU_CLKSEL_CON00` clock mux | banks written, but identical placeholders; only `configs[0]` ever used | differentiate per-FSP timings; order low→high |
| `first_init_dram_type` (LP4=7, LP4X=8, LP5=9) | `MSTR0_LPDDR4`/`MSTR0_LPDDR5` in `DDRCTL_MSTR0`; `params->base.dramtype` | handled in `.ctl.mstr0` + `phy_set_mode()` | OK |
| `sr_idle`, `pd_idle` | `DDRCTL_PWRTMG` (0x0D0C, per-freq); header `SR_IDLE`/`PD_IDLE` | **defines unused; PWRTMG is placeholder** | encode sr/pd idle into pwrtmg per freq |
| `zq_check` (0=enable) | `ZQCTL0_DIS_AUTO_ZQ` in `DDRCTL_ZQCTL0` | `.ctl.zqctl0 = 0` (auto-ZQ on) | confirm intended; expose if needed |
| `trfc_mode`, refresh | `DDRCTL_RFSHSET1TMG0..4` (per-freq), `DDRCTL_RFSHMOD0` | placeholders / reset | compute tRFC from die density |
| `per_bank_ref_en` | `DDRCTL_RFSHMOD0` / `RFSHCTL0` | not set | optional; set if used |
| `derate_en`, `ext_temp_ref` | `DDRCTL_DERATECTL0..6` (0x10100+), `DDRCTL_DERATEINT/VAL0/VAL1` (per-freq) | **not programmed** | optional MR4-derate feature |
| `auto_precharge_en`, `pageclose` | `DDRCTL_SCHED0..4` fields | reset defaults | optional scheduler tuning |
| `link_ecc_en` | `DDRCTL_DATACTL0` (0x10CA0) / DBI | not handled | out of scope for bring-up |
| `ddr_2t` | `DDRCTL_MSTR0` / DRAMSET timing | reset | set per board |
| `ddr*_odt_ohm`, `lp5_odt_ohm`, `lp5_ca_odt_ohm` (DRAM ODT) | LP5 mode registers via `DDRCTL_INITMR*`; routing `DDRCTL_ODTMAP` (0x10C9C) | ODTMAP set; **MR ODT placeholder** | encode DRAM ODT into MR (MR11/MR-CA) |
| `phy_*_odt_ohm`, pull up/dn | PHY ODT (ZQ/CAL region) — **not broken out in `sdram_phy_rk3576.h`** | **left at PHY reset (steps 27-28/31-32)** | add PHY ODT register defs + program |
| `phy_*_dq/ca/cs/clk_drv_*_ohm` (drive strength) | PHY drive (ZQ/CAL region) — **not broken out** | **reset defaults** | add drive-strength defs + program |
| `*_dq_vref_when_odten/odtoff`, `*_ca_vref` | DRAM VREF via `DDRCTL_INITMR*` (MR12 CA, MR14/MR15 DQ for LP5); PHY VrefDQ in PHY CAL | **vref left at reset** | compute & program VREF (MR + PHY) |
| `lp5_ca*_a/b_skew`, `cs/ck/cke/resetn_skew` | `DDRPHY_CA_DESKEW_CON0..6` (0x7C–0x94); DQ via `DDRPHY_OFFSET*` | **deskew never programmed** | program if board needs CA training offsets |
| `*_bytes_map`, `lp*_dq*_map`, template CA/byte/DQ swap | `DDRPHY_CASWIZZLE_CON` (0x0A98) for CA swap; `DDRPHY_OFFSET_DQ_CON0` (0x003C) + byte/DQ map regs for byte/DQ swap | **not handled** | program from board schematic "DDR Template Config" |
| `*_ch/bank/rank_mask*` | `DDRCTL_ADDRMAP1..12` (0x30004–0x30030) | **ADDRMAP never written — left at reset 0** | program address map from geometry |
| `ssmod_*` (spread spectrum) | DDRPLL in CRU (`RK3576_CRU_BASE`) | CRU handling is a `TODO` | out of scope until CRU chapter done |
| `periodic_interval` | `TRAIN_CON0_PERIODIC_WRTRN_EN` (`DDRPHY_SCHD_TRAIN_CON0`) | not set | optional periodic training |
| `uart*`, `*_log_en`, `pstore_*` | debug plumbing | n/a | not needed in from-source driver |

## Highest-value gaps (functional, blob-independent)

1. **Address map is never programmed.** `DDRCTL_ADDRMAP1..12` stay at reset 0
   while geometry comes only from the static `cap_info`. Any non-trivial
   bank/row/col/rank layout needs these registers set. This is a correctness
   gap, not just tuning.
2. **PHY ODT / drive strength / VREF left at reset** (init steps 27-28 LP4 /
   31-32 LP5). `ddrbin_param` confirms these are mandatory per-type, per-ODT
   state, per-frequency. **Register defs now added** to `sdram_phy_rk3576.h`
   from TRM Part 2 (base `ZQ_CON3/6/9` + per-DVFS `DVFS{0,1}_CON3/CON4`):
   drive `dds`/`pdds` (0x4=48/0x5=40/0x6=34/0x7=30 ohm), ODT `term`
   (0x4=60/0x2=120/0x1=240 ohm), VREF 6-bit VSEL. The driver still needs to
   *write* these (per-FSP: base point + DVFS0 + DVFS1) — the macros exist now.
   Note: extracted PHY data drive 30 ohm = code 0x7 (== reset); extracted
   PHY ODT 40 ohm has no native `term` code — needs review.
3. **CA/DQ deskew unprogrammed.** Header defines `DDRPHY_CA_DESKEW_CON0..6`
   but the driver never writes them.
4. **Per-FSP timing differentiation.** The four FREQ banks must carry distinct,
   ordered operating points, not one cloned placeholder.

## Legal value sets (RK3588 class — applies to RK3576)

- PHY drive strength / PHY ODT (LP4/LP4X/LP5, ohm): `240,120,80,60,48,40,34,30`
  (`0` = ODT disabled).
- DRAM ODT (LP4/LP4X/LP5, ohm): `0,40,48,60,80,120,240`.
- DRAM drive strength (LP4/LP4X/LP5, ohm): `40,48,60,80,120,240`.
- VREF unit: parts-per-thousand. For LP4/LP5 it must be set explicitly (auto
  only for DDR2/3/4 + LP2/3 when 0).
- JEDEC ODT-enable floors: LP4/LP4X DQ ODT only ≥ 800 MHz; DDR4 ODT only
  ≥ 625 MHz (`*_odten_freq_mhz` constraints).
- CA skew one-step (RK3528 reference formula): `1e6 / skew_freq_mhz / 128` ps.

## Ohm → register-code encoding (downstream kernel reference)

The Rockchip downstream kernel (`rockchip-linux/kernel`, develop-6.1) has **no
`rk3576-dram.h`** — the newest DRAM dt-binding is `rk3568-dram.h`, and it has no
LPDDR5 entries. What it does provide is the ohm → 5-bit PHY field encoding for
the RK3568 PHY, e.g.:

```
PHY_LPDDR4_DS_ODT_48ohm   (0xc)   /* LP4 ladder 576..25 ohm -> 0x1..0x1f */
PHY_LPDDR4X_DS_ODT_UP_*   / _DOWN_*   /* split pull-up/down for LP4X */
PHY_DDR4_DS_ODT_*
```

The ohm ladders match the `ddrbin` drive/ODT support list. **Caveats:** these
codes are for the *older RK3568 PHY*, not the RK3576 LPDDR5-capable combo PHY,
and there is no LP5 mapping. So this header is only a *pattern reference* for
the ohm→code table we must build for RK3576 — the actual RK3576 PHY drive/ODT
field encodings must come from the TRM PHY (ZQ/drive) chapter, not from here.

## Board routing template & ADC-based config selection

The tool also exposes a per-board **template** block (identical layout for
LP4/LP4X and LP5/LP5X) describing PCB-specific pin routing:

- `template_available`, `template_quad_channel`, `template_pcb_layer`,
  `template_dram_ball`, `template_max_rank` — topology descriptors.
- `ca_swap_cha_a0..a5`, `ca_swap_chb_a0..a5` — CA[0:5] pin remap per
  sub-channel (A/B). Target: `DDRPHY_CASWIZZLE_CON` (0x0A98).
- `byte0_swap..byte3_swap` — byte-lane remap (x32 = 4 bytes/channel).
- `byte[0:7]_dq[0:7]_swap` — 64 params, per-DQ remap within each byte.
  Target: `DDRPHY_OFFSET_DQ_CON0` (0x003C) + DQ-map registers.

These values are **board-specific** (from the schematic "DDR Template Config"
table) and must match the actual routing — they cannot be guessed. For the
target boards (Flipper One, ArmSoM Sige5) we need the schematic to fill them.

**ADC-based multi-config selection.** Boards can carry several DDR configs
selected at runtime by an ADC strap (`adc_value_to_ddr_config=N`, groups
numbered from 1; e.g. RK3572 ships 12 groups). This is how the real boot flow
picks among multiple DRAM configurations — it is **not** post-training
detection. This directly bears on the driver's `sdram_configs[]` selection:
the current `params = &sdram_configs[0]` placeholder and its misleading
"auto-detection handled post-training" comment should be replaced with the
real mechanism — read the SARADC strap and index the config group — once we
have the per-board group map from the schematic.

## Parameter-block binary layout (Kwiboo/rkbin-2 `ddrbin_tool.py`)

Jonas Karlman's open-source fork of the tool (`Kwiboo/rkbin-2`,
`tools/ddrbin_tool.py`) exposes the exact binary struct layout of the DDR
**parameter block** (version 7, the modern combo-PHY/LP5 layout). This is the
authoritative encoding for the values `ddrbin_param.txt` sets. Key v7 structs:

- `lp45_si_info_v7` (20 words / 0x50 B) — per-type silicon/PHY config (LP4,
  LP4X and LP5 all use this struct): `ddr_freq0_1`, `ddr_freq2_3`,
  `ddr_freq4_5` (two 12-bit MHz freqs packed per word), `drv_when_odten`,
  `drv_when_odtoff`, `odt_info`, `dq_odten_freq`, `sr_when_odten`,
  `sr_when_odtoff`, `ca_odten_freq`, `cs_drv_ca_odt_info`, `vref_when_odten`,
  `vref_when_odtoff`, `phy_dfe`, + reserved.
- `template_info_v7` (18 words / 0x48 B) — board routing: `ca_swap_0..3`,
  `byte_swap`, `dq_swap_0..7`, + reserved (one struct each for
  `lp4_4x_template_info` and `lp5_5x_template_info`).
- `hash_info` — `ch/bank/rank_mask*` (address hashing); `dq_map_info` — byte/DQ
  remap; `global_info`, per-FSP frequency indices (`lp5_freq`: mask `0xfff`).

Each parameter has a descriptor `{index, position, shift, mask, version}` giving
its exact bit location in the block — i.e. the full encoding, not just names.

**Caveat:** the fork's per-chip config blocks cover up to `rk3588` /
`rv1126b`; `rk3576` is in the chip list but has **no dedicated config block**
yet, so RK3576's exact layout is inferred from the shared v7 structs (same as
rk3588), not chip-confirmed. The tool may need the rk3588 layout as a proxy or
a small patch to run against an rk3576 blob.

### Actionable: extract real configured values (license-safe)

This unlocks reading the **actual numbers Rockchip ships** out of the binary,
without touching init code or disassembling anything:

```
./ddrbin_tool.py rk3576 -g gen_param.txt \
    rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin LPDDR5 adc_value_to_ddr_config=N
```

`gen_param.txt` then holds the real frequencies, ODT/drive ohms, VREF, slew,
CA/DQ skew, and CA/byte/DQ swap for the selected ADC group. These are
board-tuning **data values** (not code) and serve as authoritative starting
points / cross-checks for our from-source `.inc` tables and the gaps above.
(May require the rk3588-proxy caveat noted above.)

## Parameter semantics reference (RK3399 DMC binding)

The RK3399 DMC devicetree binding
(`Documentation/.../memory-controllers/rockchip,rk3399-dmc.yaml`, kernel
develop-6.1) is a *runtime DVFS* binding (kernel devfreq + ATF), not boot init,
and predates LPDDR5 — but it documents the same parameter family with units and
defaults, useful as a dictionary:

- `sr_idle` = self-refresh idle, counted in `SR_IDLE * 1024` DFI clock cycles
  (DFI clock = half the DRAM clock); `pd_idle` = power-down idle. This pins the
  units for our unused `SR_IDLE`/`PD_IDLE` defines when wiring `DDRCTL_PWRTMG`.
- `*_odt_dis_freq` (Hz): below this frequency, ODT is disabled on both DRAM and
  controller side — same JEDEC ODT-floor dependency as ddrbin's
  `*_odten_freq_mhz`.
- Candidate LP4 default ohms (RK3399-era, reference only — not the RK3576 combo
  PHY): DRAM `drv=60, dq_odt=40, ca_odt=40`; PHY `ca_drv=40, ck_cs_drv=80,
  dq_drv=80, odt=60`.

Note: nearly all these drive/ODT/idle DT properties are marked `deprecated` —
Rockchip moved the config out of the kernel DT and into the DDR blob's
parameter block. That confirms `ddrbin_param` is the modern home of these
knobs (the layer the extraction wor