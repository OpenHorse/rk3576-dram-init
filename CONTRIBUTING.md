# Contributing to rk3576-dram-init

Thanks for helping bring up open RK3576 DRAM init. This is low-level
firmware that runs before anything else — small, careful changes win.

## Ground rule: never commit proprietary firmware

The Synopsys DDR PHY training image is **not** free software and must
**never** be committed, not even temporarily. It lives under `firmware/`,
which is `.gitignore`'d except for `firmware/README.md`. Before every
push, check:

```
git status --ignored
```

Nothing under `firmware/` except `README.md` should ever be tracked. A
firmware blob in git history is very hard to remove and taints the repo.

## Licensing and sign-off

- The project is **GPL-2.0-or-later**. Every new source file must start
  with an SPDX tag: `/* SPDX-License-Identifier: GPL-2.0+ */` (`#` comment
  for shell/Makefiles).
- All commits must carry a **Developer Certificate of Origin** sign-off.
  Add it with `git commit -s`, which appends:

  ```
  Signed-off-by: Your Name <you@example.com>
  ```

  This certifies you wrote the change or have the right to submit it
  under the project licence (see https://developercertificate.org/).

## Coding style

Follow the **Linux kernel / U-Boot style** — the existing code already
does, and this project is meant to interoperate with U-Boot:

- Tabs for indentation (8 wide), K&R braces, ~80-column lines.
- Lower-case names with underscores; SoC register macros upper-case.
- No dynamic allocation, no floating point, no libc �� this runs in SRAM
  with no DRAM and no runtime.
- Use the helpers in `include/io.h`. CRU/GRF registers are write-mask
  registers �� use `rk_clrsetreg()`, never a plain `writel()`.
- When you add real register code, cite the source in a comment (TRM
  section, or "cross-checked against rkbin/downstream"), since the
  RK3576 controller/PHY register maps are not in the public TRM.

## Commits

One logical change per commit. Message format:

```
phase: short imperative summary

Longer explanation of what and why, wrapped at ~72 columns. Reference
the TRM section or hardware behaviour that motivated the change.

Signed-off-by: Your Name <you@example.com>
```

Use a subsystem prefix matching the file: `clk:`, `ddrc:`, `ddrphy:`,
`training:`, `msch:`, `detect:`, `build:`, `doc:`.

## Before you open a pull request

- `make` must build cleanly with the default toolchain. The RWX-segment
  linker warning is expected; new warnings are not.
- Keep the image inside SYSTEM_SRAM — the linker script asserts this,
  but watch the `size` output.
- If your change touches register-level init, **test it on real
  hardware** and state in the PR which board and which DRAM type
  (LPDDR4 / LPDDR4X / LPDDR5) you tested. Untested register code can
  brick a board's boot, so mark it clearly if it is untested.

## Good first contributions

- A board config (UART base, DRAM type, PMIC rails) for a specific
  RK3576 board.
- Fleshing out a single phase end to end — `clk.c` is the natural start.
- A standalone DRAM test in `memtest.c`.
