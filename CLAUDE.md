# CLAUDE.md — RK3576 TPL DRAM Init (BLOB-free)

## Mission
Write a from-source DRAM controller + PHY driver for the **Rockchip RK3576**
that runs at U-Boot **TPL** stage and initializes DRAM with **no Rockchip
DDR BLOB**. Target: upstream mainline U-Boot. This is the RK3576 equivalent
of the RK3568 RFC series `20260517-rk3568-raminit-v1` (Pavel Golikov).

This is a **U-Boot** project, not a Linux kernel project. The kernel never
touches DRAM training. Do not confuse the two.

## Hardware facts (do not guess — verify against the TRM)
- SoC: RK3576. DDR subsystem = Synopsys DesignWare **uMCTL2** controller +
  DesignWare **LPDDR4/4X/5 combo PHY**.
- Supported DRAM: LPDDR4, LPDDR4X, LPDDR5. (DDR4 unlikely on real boards —
  treat as low priority.)
- DDRPLL lives in CRU; operational base `0x27200000`. PLL register layout
  (write-enable in bits 31:16, `M`/`P`/`S`/`K` dividers) is in the TRM CRU
  chapter — see `docs/trm/`.
- TPL runs from on-chip SRAM and is **severely size-constrained**. The RK3568
  RFC noted ~59.5 KB SRAM with ~48 KB used. Confirm RK3576 SRAM budget before
  committing to embedded timing calculators vs precalculated `.inc` tables.

## Critical risk — read before writing PHY code
The RK3568 RFC is a **template, not a port**. RK3568 uses an older DDR PHY;
RK3576's LPDDR5-capable combo PHY is a different generation. The hard part of
BLOB-free init is PHY training:
- Synopsys LPDDR4/5 PHYs normally need the Synopsys PHY training firmware
  (the `.bin` that Rockchip ships inside the DDR BLOB).
- Confirm early whether RK3576 can train without that firmware (as RK3568 did)
  or whether write-leveling / read-DQS / CA training must be reimplemented.
- If firmware-free training is not feasible, surface this immediately rather
  than writing dead code.

## Reference material (in this repo)
- `docs/rk3568-raminit-rfc/` — the full 18-patch RK3568 RFC. Primary
  architectural template. Mirror its file layout and DM/OF_PLATDATA approach.
- `docs/trm/` — RK3576 TRM extracts (CRU/DDRPLL + DDR controller chapters).
  Authoritative for register offsets and reset values. Cite page numbers in
  code comments.
- `docs/mainline-status.md` — RK3576 kernel enablement status (context only).

## Code layout (mirror RK3568)
```
drivers/ram/rockchip/sdram_rk3576.c          # controller + init entry
drivers/ram/rockchip/sdram-rk3576-*.inc      # precalculated timing tables
arch/arm/include/asm/arch-rockchip/sdram_rk3576.h
arch/arm/include/asm/arch-rockchip/sdram_phy_rk3576.h
arch/arm/mach-rockchip/rk3576/syscon_rk3576.c
arch/arm/dts/rk3576-u-boot.dtsi              # DMC reg spaces + syscons
configs/<board>_defconfig                    # CONFIG_RAM_ROCKCHIP_LPDDR4/5
```

## Constraints / conventions
- U-Boot driver model (DM). TPL uses **OF_PLATDATA** — no live DT parsing;
  rely on dtoc-generated platdata. Watch the `clk_rk3568.c` OF_PLATDATA build
  fixes in the RFC for the pattern.
- Kernel/U-Boot C style. Every patch must pass
  `scripts/checkpatch.pl --strict` before it is considered done.
- Keep TPL size down: prefer precalculated `.inc` timing tables over an
  embedded calculator unless SRAM budget proves otherwise.
- Register writes: use `writel`/`clrsetbits_le32`, comment every magic value
  with its TRM register name + page.
- One logical change per commit. Match the RFC's commit granularity so the
  series is reviewable on the u-boot list.

## Build & test workflow
```bash
# Toolchain: aarch64 cross-compiler
export CROSS_COMPILE=aarch64-linux-gnu-  ARCH=arm64
make <board>_defconfig
make -j$(nproc)                 # produces TPL, SPL, u-boot proper
# TPL size check:
size spl/u-boot-spl tpl/u-boot-tpl
```
Test on real RK3576 hardware (e.g. ArmSoM Sige5 / Radxa Rock 4D). Boot over
UART; a working TPL prints DRAM size and hands off to SPL. There is no
meaningful emulation path for DRAM training — hardware is required.

## Workflow expectations for Claude Code
1. Before touching PHY/controller code, read the relevant TRM chapter in
   `docs/trm/` and the matching RK3568 RFC patch. State which patch you are
   adapting.
2. Work patch-by-patch, smallest viable change first. Build after every step.
3. Never invent register offsets or reset values — if not in `docs/`, say so
   and stop.
4. Flag any point where RK3576 diverges from RK3568 (especially PHY).
