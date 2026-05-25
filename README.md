# RK3576 BLOB-free TPL DRAM Init

Open-source DRAM controller and PHY driver for the Rockchip RK3576 SoC,
running at U-Boot TPL stage without the Rockchip DDR binary blob.

This is the RK3576 equivalent of the RK3568 RFC series
`20260517-rk3568-raminit-v1` (Pavel Golikov), targeting upstream mainline
U-Boot.

## Background

Rockchip ships DRAM initialization as a closed binary blob (`ddr.bin`).
Upstream U-Boot requires open-source drivers for all SoC-specific init.
This project provides that driver for the RK3576.

Primary target board: **Flipper One** (`rk3576-flipper-one-rev-f0b0c1`,
8 GB LPDDR5). Also enables the ArmSoM Sige5 (`sige5-rk3576_defconfig`) as an
immediately testable platform. Addresses the open task in
[flipperdevices/flipperone-linux-build-scripts#56](https://github.com/flipperdevices/flipperone-linux-build-scripts/issues/56).

## Hardware

**SoC:** Rockchip RK3576

**DDR subsystem:** Two independent channels, each containing:
- Synopsys DesignWare uMCTL2 DDRCTL
- Synopsys DesignWare LPDDR4/4X/5 combo PHY

**Supported DRAM types:** LPDDR4, LPDDR4X, LPDDR5

**PHY training:** The RK3576 combo PHY includes a hardware training engine
controlled by `SCHD_TRAIN_CON0[0]` (phy_train_en) and `SCHD_TRAIN_CON0[1]`
(phy_train_done). No Synopsys PHY training firmware (`.bin`) is required.
This was confirmed from TRM Part 2 p.965 and matches the approach used on
RK3568.

**SRAM budget:** ~248 KB between `boost.bin` (0x3ff82000) and SPL
(0x3ffc0000). Precalculated `.inc` timing tables are used to stay within
this limit rather than an embedded calculator.

## Repository Structure

```
rk3576-dram-init/
├── docs/
│   ├── trm/
│   │   ├── Rockchip_RK3576_TRM_V1.2_Part1.docx   # TRM Part 1 (addresses, CRU)
│   │   ├── Rockchip_RK3576_TRM_V1.2_Part2.pdf    # TRM Part 2 (DDR chapter)
│   │   ├── dmc_overview.txt                       # DMC chapter extract
│   │   ├── dmc_appnotes.txt                       # TRM §7.6 init procedure
│   │   └── dmc_phy_regsummary.txt                 # PHY register summary
│   ├── rk3568-raminit-rfc/                        # RK3568 RFC (architectural template)
│   │   └── 18] rockchip_ rk3568_...pdf
│   ├── mainline-status.md                         # RK3576 kernel enablement status
│   └── rk3576-ddr-research.md                     # DDR blob analysis, FSP freqs
├── patches/                                       # RFC patch series (v1, 14 patches)
│   ├── v1-0000-cover-letter.patch
│   └── v1-0001 … v1-0014-*.patch
├── u-boot/                                        # Mainline U-Boot tree (git subdir)
│   ├── arch/arm/dts/rk3576-u-boot.dtsi            # DMC reg spaces + DDR GRF node
│   ├── arch/arm/include/asm/arch-rockchip/
│   │   ├── sdram_pctl_rk3576.h                    # uMCTL2 register layout
│   │   ├── sdram_rk3576.h                         # Platform structs and addresses
│   │   └── sdram_phy_rk3576.h                     # Combo PHY register layout
│   ├── arch/arm/mach-rockchip/
│   │   ├── Kconfig                                # RK3576 imply lines for TPL
│   │   └── rk3576/
│   │       ├── Kconfig                            # TPL_TEXT_BASE
│   │       └── syscon_rk3576.c                    # DDR GRF syscon entry
│   ├── configs/sige5-rk3576_defconfig             # TPL enabled for Sige5
│   ├── drivers/clk/rockchip/clk_rk3576.c         # OF_PLATDATA + XPL_BUILD fixes
│   ├── drivers/ram/rockchip/
│   │   ├── Kconfig                                # RAM_ROCKCHIP_LPDDR5 option
│   │   ├── sdram_common.c                         # LPDDR4X/LPDDR5 type support
│   │   ├── sdram_rk3576.c                         # Controller + PHY driver
│   │   ├── sdram-rk3576-lpddr4-detect-1560.inc   # LPDDR4 timing table (placeholder)
│   │   └── sdram-rk3576-lpddr5-detect-2133.inc   # LPDDR5 timing table (placeholder)
│   ├── drivers/serial/serial_rockchip.c           # DM_DRIVER_ALIAS for RK3576 UART
│   └── drivers/sysreset/Makefile                  # XPL build guard
└── README.md
```

The working branch is `rfc-rk3576-dram-init-v1` inside `u-boot/`.

## New Files (driver implementation)

### `sdram_pctl_rk3576.h`
uMCTL2 DDRCTL register layout. Defines FREQ-banked timing register offsets
(four 1 MB banks at `DDRCTL_FREQ_BASE(n)` = 0x0/0x100000/0x200000/0x300000),
global registers at 0x10000+, port QoS at 0x20000+, and address map at
0x30000+. 130 defines, verified against TRM Part 2.

### `sdram_rk3576.h`
Platform header. Defines physical base addresses for DDRCTL0/1 and DDRPHY0/1,
DDR_GRF and PMU1GRF offsets, DDR_CRU clock-select bits, and the key structs:
- `rk3576_ddrctl_freq_params` — per-frequency timing block (populated by `.inc` tables)
- `rk3576_ddrctl_global_params` — global static DDRCTL registers
- `rk3576_sdram_channel` / `rk3576_sdram_params` — top-level param struct

### `sdram_phy_rk3576.h`
Combo PHY register layout. 123 defines covering GNR (controller mode),
CAL, LP, GATE, OFFSET R/W/D/C/O, WR_LVL, CA_DESKEW, MDLL, DVFS, ZQ, CBT,
and the training/FSM/command registers. Field macros verified against TRM
Part 2 pp.808–980.

### `sdram_rk3576.c`
Controller + PHY driver implementing:
- TRM §7.6.2: LPDDR4 init (37 steps)
- TRM §7.6.3: LPDDR5 init (42 steps)
- Hardware PHY training engine (`phy_train`)
- ZQ calibration (`phy_zq_calibrate`, TRM pp.860–862)
- PMU1GRF OS_REG2/3 write for SPL + Linux (`sdram_org_config`)
- Two-channel loop (`sdram_init`)

### `sdram-rk3576-lpddr5-detect-2133.inc`
LPDDR5 timing table at PHY 2x clock 2133 MHz (CK=1067 MHz, data rate ≈
LP5-8533). Values are **TRM reset defaults — not hardware-correct**.
`mstr0 = 0x01080040` (BL16, 2-rank). Capacity: 8 GB / 2 ch.

### `sdram-rk3576-lpddr4-detect-1560.inc`
LPDDR4 timing table at CK=1560 MHz. Values are **TRM reset defaults —
not hardware-correct**. `mstr0 = 0x01080020` (BL16, 2-rank).
Capacity: 4 GB / 2 ch.

## Build

Requires an AArch64 cross-compiler (e.g. `aarch64-linux-gnu-gcc`).

```bash
cd u-boot
git checkout rfc-rk3576-dram-init-v1

export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

# ArmSoM Sige5 (compile-test target)
make sige5-rk3576_defconfig
make -j$(nproc)

# Size check — TPL must fit in SRAM
size tpl/u-boot-tpl

# checkpatch on the full series
for p in ../patches/v1-00[0-9][1-9]-*.patch ../patches/v1-001[0-4]-*.patch; do
    scripts/checkpatch.pl --strict "$p"
done
```

Expected: 0 errors, 0 blocking warnings per patch. The 12 pre-existing
`IS_ENABLED` warnings in `clk_rk3576.c` are false positives and can be
ignored.

## Testing on Hardware

There is no meaningful emulation path for DRAM training — real hardware is
required. U-Boot TPL prints DRAM size over UART and hands off to SPL if
training succeeds.

1. Build TPL + SPL + U-Boot proper as above.
2. Package with `tools/mkimage` (RK3576 idbloader format).
3. Flash to SD card or eMMC.
4. Connect UART (1500000 baud on Flipper One / Sige5).
5. A successful boot prints:
   ```
   U-Boot TPL ...
   DRAM: 8 GiB
   ```
   followed by SPL banner.

**Note:** The timing tables currently contain TRM reset defaults and will
not produce correct DRAM operation. Hardware bring-up requires real timing
values (see Known Issues below).

## Submitting the RFC

```bash
cd u-boot
git send-email \
    --to u-boot@lists.denx.de \
    --cc kever.yang@rock-chips.com \
    --cc philipp.tomsich@vrull.eu \
    ../patches/v1-*.patch
```

Patches are on branch `rfc-rk3576-dram-init-v1`. The cover letter is
`patches/v1-0000-cover-letter.patch`.

## Known Issues / TODO

### Timing tables contain placeholder values
`sdram-rk3576-lpddr5-detect-2133.inc` and `sdram-rk3576-lpddr4-detect-1560.inc`
use TRM register reset defaults throughout. Hardware bring-up will fail until
correct values are calculated. Required inputs:

- **JEDEC JESD209-5B** (LPDDR5) or **JESD209-4D** (LPDDR4) — timing
  parameters (`tRFC`, `tRCD`, `tRP`, `tRAS`, etc.)
- **Synopsys uMCTL2 Software Reference Specification (SRS)** — field
  encoding rules for `DRAMSETxTMGy`, `DFITMGy`, `RFSHSETxTMGy`
- **Actual DRAM part number** for the Flipper One — determines `tRFC`,
  RL/WL values, and `INITMR` encoding
- `dfitmg0`/`dfitmg1` `tDFI_WRDATA` and `tDFI_RDDATA_EN` — PHY-specific
  latencies not in the TRM

### DDR_CRU base address discrepancy
`sdram_rk3576.h` defines:
```c
#define RK3576_DDR0CRU_BASE  0x27210000
#define RK3576_DDR1CRU_BASE  0x27220000
```
`docs/rk3576-ddr-research.md` lists DDR0_CRU as `0x27228000` and DDR1_CRU
as `0x27230000`. **These cannot both be correct.** The header values were
taken from TRM Part 1 Table 1-1; the research doc values were extracted from
Rockchip's blob. Verify against TRM Part 1 before hardware bring-up.

### LPDDR5 MR1/MR2 encoding
`initmr0` for LPDDR5 uses TRM reset value `0x0`. The correct RL/WL encoding
for the chosen speed grade must be calculated from JESD209-5B Table 14.

### PHY vref and ODT
Steps 27–28 (LPDDR4) / 31–32 (LPDDR5) in `ddr_init_channel()` use PHY
reset defaults. Real values depend on the PCB impedance and must be tuned
on hardware.

### Flipper One defconfig pending
`configs/flipper-one-rk3576_defconfig` will be added once the Flipper One
DTS (`rk3576-flipper-one-rev-f0b0c1`) is accepted upstream. Track progress
in the Flipper u-boot fork: `flipperdevices/u-boot` branch `rk3576`.

## References

- **RK3576 TRM V1.2** — `docs/trm/`. Authoritative for all register offsets.
  Do not invent values not found here.
- **Synopsys uMCTL2 Databook** — DDRCTL register field encoding. Not
  redistributable; obtain from Synopsys or Rockchip NDAs.
- **RK3568 RFC series** (`20260517-rk3568-raminit-v1`, Pavel Golikov) —
  `docs/rk3568-raminit-rfc/`. Primary architectural template.
- **JEDEC JESD209-5B** (LPDDR5), **JESD209-4D** (LPDDR4) — timing parameters
  for timing table calculation.
- **U-Boot mailing list:** u-boot@lists.denx.de
- **Flipper One open task:** flipperdevices/flipperone-linux-build-scripts#56

## License

Driver code is GPL-2.0+ in accordance with U-Boot conventions.
