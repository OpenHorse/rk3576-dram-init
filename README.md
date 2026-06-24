# RK3576 BLOB-free TPL DRAM init

An open-source DRAM controller and PHY driver for the Rockchip RK3576 SoC,
running at the U-Boot **TPL** stage without the Rockchip DDR binary blob.
The goal is upstream mainline U-Boot.

It is the RK3576 counterpart to Pavel Golikov's RK3568 RFC series (see
`docs/rk3568-raminit-rfc/`), and follows the same structure.

> **Status: work in progress / RFC.** The driver builds and is
> `checkpatch --strict` clean, but the timing tables currently hold TRM reset
> defaults, so it does **not** yet bring up DRAM on real hardware. See
> [Status and known gaps](#status-and-known-gaps).

## What is in this repository

This repo holds the **patch series and supporting material**, not a forked
U-Boot tree. The driver is developed against mainline U-Boot and delivered as
patches you apply on top of it.

```
.
├── patches/         RFC v1 series (against mainline U-Boot)
├── patches-v2/      RFC v2 series (current)
├── docs/
│   ├── mainline-status.md            RK3576 kernel enablement status (context)
│   ├── rk3576-ddr-research.md        DDR subsystem notes
│   ├── rkbin-param-gap-analysis.md   ddrbin param -> driver register mapping
│   └── rk3568-raminit-rfc/           pointer to Pavel Golikov's RK3568 RFC
├── tools/
│   └── ddr-extract/  read board DDR parameters from the vendor ddrbin tool
├── CONTRIBUTING.md
├── LICENSE           GPL-2.0
└── README.md
```

The RK3576 TRM is proprietary and is **not** included here; the driver cites
TRM page numbers in comments. The Synopsys uMCTL2 Databook is likewise not
redistributable. A local U-Boot working tree and the Rockchip DDR blob are
kept out of git (see `.gitignore`).

## Hardware

- **SoC:** Rockchip RK3576.
- **DDR subsystem:** two independent channels, each with a Synopsys DesignWare
  uMCTL2 controller and a DesignWare LPDDR4/4X/5 combo PHY.
- **Supported DRAM:** LPDDR4, LPDDR4X, LPDDR5.
- **PHY training:** the combo PHY has a hardware training engine
  (`SCHD_TRAIN_CON0`), so no Synopsys training firmware blob is required —
  confirmed from the TRM and consistent with the RK3568 approach.

Real operating points (from the shipped Rockchip DDR blob filename):
LPDDR4/4X at 2112 MHz and LPDDR5 at 2736 MHz.

## Building and testing

Apply the current series onto a mainline U-Boot checkout and build for a
target board (the ArmSoM Sige5 is a convenient compile/test target), e.g.:

```bash
git clone https://source.denx.de/u-boot/u-boot.git
cd u-boot
git am ../rk3576-dram-init/patches-v2/*.patch

export CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64
make sige5-rk3576_defconfig
make -j"$(nproc)"
size tpl/u-boot-tpl          # TPL must fit in SRAM

scripts/checkpatch.pl --strict ../rk3576-dram-init/patches-v2/*.patch
```

There is no meaningful emulation path for DRAM training — real hardware is
required. A working TPL prints the DRAM size over UART (1500000 baud) and
hands off to SPL.

## Status and known gaps

- **Timing tables are placeholders.** The `.inc` tables use TRM reset values;
  hardware bring-up needs real values computed from JEDEC (JESD209-5B /
  JESD209-4D) and the Synopsys uMCTL2 SRS, plus the actual DRAM part data.
- **PHY drive/ODT/VREF** register definitions are in place (from the TRM); the
  per-DVFS overrides and the VREF code computation are still to do.
- **Address map programming** (`DDRCTL_ADDRMAP*`) from the DRAM geometry is not
  yet wired up.
- **Not hardware-validated yet.** This is pre-bring-up.

`tools/ddr-extract/` reads the board's real DDR parameters (frequencies,
drive/ODT/VREF, address masks) from Rockchip's own `ddrbin` tool, and
`docs/rkbin-param-gap-analysis.md` maps each to the driver registers and
records what still has to be computed rather than read. No blob-derived data
is committed here; regenerate it locally per that tool's README.

## Relationship to upstream

The RK3576 series intentionally tracks Pavel Golikov's RK3568 raminit RFC and
the surrounding U-Boot review. Per maintainer feedback, the RK3576 series is
held until the RK3568 parent series settles, to avoid two parallel reviews.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Patches should follow U-Boot
conventions and pass `scripts/checkpatch.pl --strict`.

## License

GPL-2.0, in line with U-Boot. See [LICENSE](LICENSE).
