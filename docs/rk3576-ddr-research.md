# RK3576 DDR Subsystem Research Notes

Generated 2026-05-24. Sources: TRM Part 1 (text extraction), downstream kernel
(armbian/linux-rockchip rk3576-6.1-dev-2024_04_19), Rockchip rkbin v1.09 metadata,
Flipper One issue #56 community analysis.

---

## 1. Address Map (authoritative — TRM Part 1, Table 1-1)

| Block      | Address      | Size   | Notes |
|------------|--------------|--------|-------|
| DDRCTL0    | 0x28000000   | 16 MB  | uMCTL2 channel 0; PHY regs within this window |
| DDRCTL1    | 0x29000000   | 16 MB  | uMCTL2 channel 1 |
| DDRPHY0    | 0x2A020000   | 64 KB  | PHY0 APB interface |
| DDRPHY1    | 0x2A030000   | 64 KB  | PHY1 APB interface |
| DDRMON0    | 0x2A000000   | 64 KB  | Performance monitor 0 |
| DDRMON1    | 0x2A010000   | 64 KB  | Performance monitor 1 |
| DDR_WDT    | 0x2A040000   | 64 KB  | DDR watchdog |
| DMA2DDR    | 0x2A100000   | 64 KB  | DMA-to-DDR bridge |
| DDR_GRF    | 0x26012000   | 8 KB   | DDR Global Register File |
| DDR0_CRU   | 0x27228000   | 32 KB  | DDR0 channel CRU (D0APLL, D0BPLL) |
| DDR1_CRU   | 0x27230000   | 32 KB  | DDR1 channel CRU (D1APLL, D1BPLL) |
| DDR_PVTPLL | 0x27280000   | 32 KB  | DDR PVT PLL |
| CRU        | 0x27200000   | 32 KB  | Main CRU (GPLL etc, NOT the DDR PLLs) |
| PMU1GRF    | 0x26026000   | —      | PMU1 GRF (OS_REG2 at +0x208) |
| MSCH_DDR_PORT | 0x40000000 | 16 GB | DRAM physical address space |

**WARNING:** The `kendun555-svg/ddr-trainer` repo uses addresses from RK3588
(0xF7000000 range, 0xFF010000 for CRU). Those are completely wrong for RK3576.
Do not use them. All base addresses must come from TRM Part 1, Table 1-1.

---

## 2. DDR PLL Architecture

RK3576 has **two independent DDR channels** each with their own CRU:
- Channel 0: DDR0_CRU at 0x27228000, contains **D0APLL** and **D0BPLL**
- Channel 1: DDR1_CRU at 0x27230000, contains **D1APLL** and **D1BPLL**

PLL type is **DDRPLL** (distinct from FRACPLL and INTPLL — see TRM Table 2).
DDRPLL parameters: Fin 6–300 MHz, Fvco 3300–6600 MHz, Fout 51.6–6600 MHz.
Dividers: M (64–1023), P (1–63), S (0–6).
Write-enable mechanism: bits [31:16] of each CON register are write-enable.

The DPLL offset within DDR0_CRU is **0x0040** (PLL index 2, 2 × 0x20 bytes).
The ddr-trainer comment notes this was 0x80 in an earlier version (wrong: that
would be GPLL index 4).

Main CRU PLL layout (from TRM register table):
- 0x0000: BPLL_CON0 (reset 0x00000190)
- 0x0160: VPLL_CON0
- 0x0180: AUPLL_CON0

DDR PLLs live in DDR0_CRU/DDR1_CRU, not in the main CRU.

---

## 3. DDR Controller (uMCTL2)

RK3576 uses **Synopsys DesignWare uMCTL2**. Standard uMCTL2 register layout:
- MSTR (0x0000): master register, LPDDR5 = bit 6
- STAT (0x0004): operating mode
- MRCTRL0/1 (0x0010/0x0014): mode register r/w
- PWRCTL (0x0030): power-down / self-refresh
- DERATEEN (0x0020): temperature derating enable (blob: derate_en=1)
- RFSHCTL0 (0x0050): refresh config, per-bank refresh (blob: per_bank_ref_en=1)
- DRAMTMG0–17: DRAM timing registers
- DFIMISC (0x01B0): DFI init start/complete
- DFISTAT (0x01BC): DFI init complete status
- ADDRMAP0–11 (0x0200–0x022C): address mapping

The uMCTL2 register map is compatible with the existing `sdram_pctl_px30.h`
header — **W5 decision: extend rather than fork**, but verify offsets against
TRM Part 2 once available.

---

## 4. DRAM Type and Target Frequencies

From Rockchip rkbin v1.09 blob name:
`rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.09.bin`

- **LPDDR4/4X** max: 2112 MHz (= 4224 Mbps per pin)
- **LPDDR5** max: 2736 MHz (= 5472 MT/s per pin)

**Flipper One uses 8 GB LPDDR5** — LPDDR5 at 2736 MHz is the primary target.
LPDDR4X is secondary (other boards, e.g. those without LPDDR5).

Blob v1.09 build: 2024-11-07 (`rk3576: ddr: update to v1.09 20241107`).

---

## 5. Boot Frequency and FSP

From blob parameter extraction (kendun555-svg, hand-verified against blob name):
- **FSP0 (boot):** 528 MHz — all training done at this frequency
- **FSP1:** 1068 MHz
- **FSP2:** 1560 MHz
- **Target:** 2112 MHz (LPDDR4X) / 2736 MHz (LPDDR5) — reached via runtime DFS

FSP = Frequency Set Point. Training is done at FSP0. Frequency scaling to higher
FSPs happens at runtime via ATF + DDR MCU (not in TPL).

---

## 6. Key Parameters from Blob Analysis (LPDDR4X)

These were extracted from the v1.09 blob using `ddrbin_tool`. Treat as reference
until verified on hardware:

| Parameter | Value | Description |
|-----------|-------|-------------|
| fsp0_freq | 528 MHz | Boot/training frequency |
| odt_en_freq | 800 MHz | ODT disabled below this |
| per_bank_ref_en | 1 | Per-bank refresh enabled |
| derate_en | 1 | Temperature derating enabled |
| PHY drive (LPDDR4X) | 30 Ω | PHY_CON2 TSEL code |
| PHY ODT (LPDDR4X) | 40 Ω | PHY_CON2 OTSEL code |
| DRAM DQ ODT MR11 | 40 Ω (RZQ/6) | JEDEC LPDDR4X ODT |
| DRAM CA ODT MR22 | 120 Ω (RZQ/2) | SOC ODT |
| DRAM VREF MR14 | 0x20 (~22.8%) | Initial VREF, range 1 |

---

## 7. PHY Architecture — Open Question (W11e)

**What we know:**
- RK3576 `rk3576-dfi` in the downstream kernel calls `rk3588_dfi_init` — the
  PHY monitoring architecture is shared with RK3588.
- RK3576 `rk3576-dmc` also uses `rk3588_dmc_init` — same frequency scaling path
  via ATF + SIP SMC calls, not direct register access from Linux.
- The ddr-trainer reverse-engineering attempt defines `PHY_TRAIN_CTRL` (0x0040)
  with bits for WRLVL/GATE/RDDSK/WRDSK/VREF/CA, and `PHY_TRAIN_STATUS` —
  suggesting the PHY has a **hardware training engine** (no firmware required).
- The blob size (~300 KB) is consistent with a self-contained training
  implementation, not the 50–200 KB Synopsys firmware plus a wrapper.
- The CLAUDE.md describes it as "DesignWare LPDDR4/4X/5 combo PHY"; the
  ddr-trainer calls it "Rockchip/Cadence combo PHY". Both may be partially right.

**Preliminary answer:** Firmware-free training is likely feasible, similar to
RK3568. The PHY appears to have a hardware training engine. **This needs
confirmation from TRM Part 2** (the DDR PHY chapter).

**Action needed:** Obtain TRM Part 2 (or the DDR PHY register map separately).
Contact Collabora (Alexey Charkov, alchark@flipper.net) who is aware of the
RK3568 RFC — they may have PHY documentation.

---

## 8. SRAM Budget

From Flipper One U-Boot boot chain analysis:
- Boost binary loads at: **0x3ff81000** (SRAM, tiny ~32-byte stub)
- SPL loads at: **0x3ffc0000** (SRAM, max size 0x40000 = 256 KB)
- Available for TPL: 0x3ff82000 → 0x3ffbffff ≈ **~248 KB**

248 KB is vastly more than the RK3568 RFC's ~12 KB margin. Precalculated `.inc`
timing tables (W8, W9, W10) are the right approach and will fit comfortably.

---

## 9. Community Status

- No open-source DRAM init exists for RK3576 in any public tree
  (both mainline and ArmSoM downstream have `return (-1)` stubs for TPL)
- Flipper tracks the blob blocker at: flipperdevices/flipperone-linux-build-scripts#56
- One reverse-engineering attempt exists (kendun555-svg/ddr-trainer) but has
  wrong base addresses, AI-generated C, and should not be used as reference code.
  The extracted **parameters** may be useful cross-references once we have TRM Part 2.
- RK3568 RFC (20260517-rk3568-raminit-v1) is the closest reference — Alexey
  Charkov at Flipper explicitly linked it in issue #56.

---

## 10. Immediate Next Steps (before writing PHY code)

1. **Obtain TRM Part 2** — the DDR controller + PHY chapter. Without it, W11b
   (PHY register definitions) cannot be written correctly. Ask Collabora or
   Rockchip for the PHY chapter / register map.

2. **Start W1–W4** — clk/syscon OF_PLATDATA fixes; these are independent of the
   PHY question and are needed regardless.

3. **Reach out to `br245785`** — commented in issue #56 "I've written warmups
   for LPDDR5x"; has LPDDR5 training experience. Potential collaborator.

4. **Do not use `kendun555-svg/ddr-trainer`** base addresses. Parameters may be
   useful reference only, after hardware verification.
