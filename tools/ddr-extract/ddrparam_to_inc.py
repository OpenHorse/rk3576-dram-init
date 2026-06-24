#!/usr/bin/env python3
"""Map an extracted ddrbin gen_param.txt onto the RK3576 driver structures.

Buckets every *populated* value by which register/struct it feeds, separating
[BLOB] (board truth, usable now) from [TODO] (controller timings to compute
from JEDEC + uMCTL2 SRS). Tolerates the UTF-16 PowerShell `>` produces.

Usage: ddrparam_to_inc.py <gen_param.txt> [out.txt]
"""
import re
import sys

PHY_SUFFIXES = {
    "dq_drv_when_odten_ohm":   "PHY DQ drive, ODT on   -> PHY ZQ/drive reg (TBD)",
    "dq_drv_when_odtoff_ohm":  "PHY DQ drive, ODT off  -> PHY ZQ/drive reg (TBD)",
    "ca_drv_when_odten_ohm":   "PHY CA drive, ODT on   -> PHY ZQ/drive reg (TBD)",
    "ca_drv_when_odtoff_ohm":  "PHY CA drive, ODT off  -> PHY ZQ/drive reg (TBD)",
    "clk_drv_when_odten_ohm":  "PHY CLK drive, ODT on  -> PHY ZQ/drive reg (TBD)",
    "clk_drv_when_odtoff_ohm": "PHY CLK drive, ODT off -> PHY ZQ/drive reg (TBD)",
    "cs_drv_odten":            "PHY CS drive, ODT on   -> PHY ZQ/drive reg (TBD)",
    "cs_drv_odtoff":           "PHY CS drive, ODT off  -> PHY ZQ/drive reg (TBD)",
    "odt_ohm":                 "PHY ODT impedance      -> DDRPHY_ZQ_CON* (TBD)",
    "ca_odt_ohm":              "DRAM CA ODT            -> MR (CA ODT)",
    "dq_vref_when_odten":      "VREF DQ, ODT on        -> MR14/15 + PHY VrefDQ",
    "dq_vref_when_odtoff":     "VREF DQ, ODT off       -> MR14/15 + PHY VrefDQ",
    "ca_vref_when_odten":      "VREF CA, ODT on        -> MR12 (CA VREF)",
    "ca_vref_when_odtoff":     "VREF CA, ODT off       -> MR12 (CA VREF)",
    "dq_sr_when_odten":        "PHY DQ slew, ODT on    -> PHY slew reg (TBD)",
    "dq_sr_when_odtoff":       "PHY DQ slew, ODT off   -> PHY slew reg (TBD)",
    "wck_odt":                 "LP5 WCK ODT            -> PHY WCK ODT (TBD)",
    "nt_odt":                  "LP5 non-target ODT     -> MR / PHY",
}
SKEW_RE = re.compile(r"_(ca|cs|ck[np]?|cke|odt|ba|bg|ras|cas|we|actn|resetn|dq\d)\d*_?[ab]?_?skew$")
SWAP_RE = re.compile(r"swap$")
MASK_RE = re.compile(r"_(ch|bank|rank)_mask\d$")
FLAG_MAP = {
    "zq_check": "DDRCTL_ZQCTL0.dis_auto_zq (0=enable)",
    "trfc_mode": "DDRCTL_RFSHSET1TMG* (tRFC selection)",
    "derate_en": "DDRCTL_DERATECTL0..6 + DERATEINT/VAL",
    "per_bank_ref_en": "DDRCTL_RFSHMOD0",
    "link_ecc_en": "DDRCTL_DATACTL0",
    "ddr_2t": "DDRCTL_MSTR0 / DRAMSET 2T mode",
    "pageclose": "DDRCTL_SCHED*",
    "boot_fsp": "which FREQ bank is the boot/final point",
    "first_init_dram_type": "DDRCTL_MSTR0 type (LP4=7,LP4X=8,LP5=9)",
    "sr_idle": "DDRCTL_PWRTMG self-refresh idle [header SR_IDLE]",
    "pd_idle": "DDRCTL_PWRTMG power-down idle [header PD_IDLE]",
    "channel mask": "active channels",
    "stride type": "address interleave/stride",
    "periodic_interval": "periodic training interval (x100ms)",
}


def is_set(v):
    if v == "":
        return False
    try:
        return int(v, 0) != 0
    except ValueError:
        return True


def parse(path):
    raw = open(path, "rb").read()
    text = None
    for enc in ("utf-8-sig", "utf-16", "latin-1"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeError:
            continue
    vals = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or "=" not in line or line.startswith(("start tag", "#", "/*")):
            continue
        if line == "end":
            break
        k, _, v = line.partition("=")
        vals[k.strip()] = v.strip()
    return vals


def bucket(vals):
    freqs, phy, skew, swap, masks, flags, other = {}, {}, {}, {}, {}, {}, {}
    for k, v in vals.items():
        if k in FLAG_MAP:
            flags[k] = v
            continue
        if not is_set(v):
            continue
        if k.endswith("_freq") or k.endswith("_freq_mhz"):
            freqs[k] = v
        elif MASK_RE.search(k):
            masks[k] = v
        elif SWAP_RE.search(k) or k.startswith(("ca_swap", "byte", "dq_swap")):
            swap[k] = v
        elif SKEW_RE.search(k):
            skew[k] = v
        else:
            suffix = next((s for s in PHY_SUFFIXES if k.endswith(s)), None)
            if suffix:
                phy[k] = (v, PHY_SUFFIXES[suffix])
            else:
                other[k] = v
    return freqs, phy, skew, swap, masks, flags, other


def section(title, note=""):
    print("\n" + "=" * 72)
    print(title + (("  -> " + note) if note else ""))
    print("=" * 72)


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: ddrparam_to_inc.py <gen_param.txt> [out.txt]")
    if len(sys.argv) == 3:
        sys.stdout = open(sys.argv[2], "w", encoding="utf-8")
    vals = parse(sys.argv[1])
    if not vals:
        sys.exit("no parameters parsed from " + sys.argv[1])
    freqs, phy, skew, swap, masks, flags, other = bucket(vals)
    print("# RK3576 from-source mapping of extracted blob parameters")
    print("# source:", sys.argv[1])
    section("[BLOB] Operating frequencies (MHz)", "DDRCTL_FREQ_BASE(n) banks; f1<f2<...<final")
    for k in sorted(freqs):
        print("  %-32s = %s" % (k, freqs[k]))
    section("[BLOB] PHY ODT / drive / VREF / slew", "driver leaves these at PHY reset")
    for k in sorted(phy):
        print("  %-38s = %6s   %s" % (k, phy[k][0], phy[k][1]))
    if not phy:
        print("  (none)")
    section("[BLOB] CA / DQ / CK skew", "DDRPHY_CA_DESKEW_CON0..6 / OFFSET*")
    for k in sorted(skew):
        print("  %-32s = %s" % (k, skew[k]))
    if not skew:
        print("  (none -> board uses zero CA skew)")
    section("[BLOB] CA / byte / DQ swap (routing)", "DDRPHY_CASWIZZLE_CON / OFFSET_DQ_CON0")
    for k in sorted(swap):
        print("  %-32s = %s" % (k, swap[k]))
    if not swap:
        print("  (none)")
    section("[BLOB] Address-hash masks", "DDRCTL_ADDRMAP1..12 (convert mask->addrmap)")
    for k in sorted(masks):
        print("  %-32s = %s" % (k, masks[k]))
    if not masks:
        print("  (none)")
    section("[BLOB] Feature flags", "controller config registers")
    for k in sorted(flags):
        print("  %-22s = %8s   %s" % (k, flags[k], FLAG_MAP[k]))
    if other:
        section("[BLOB] Other populated params")
        for k in sorted(other):
            print("  %-32s = %s" % (k, other[k]))
    section("[TODO] NOT in the blob param block -- compute from JEDEC + uMCTL2 SRS")
    for r in ("DDRCTL_DRAMSET1TMG0..30  core SDRAM timing (tRAS/tRC/tFAW/wr2pre/...)",
              "DDRCTL_DFITMG0..5        DFI write/read latencies for this PHY",
              "DDRCTL_RFSHSET1TMG*      tRFC from die density",
              "DDRCTL_INITMR0..3        MR encodings (RL/WL/BL, VREF MRs)",
              "DDRCTL_ZQSET1TMG*, RANKTMG*, PWRTMG (use sr/pd idle above)"):
        print("  " + r)
    print("\n  -> see docs/rkbin-param-gap-analysis.md for the target registers.")


if __name__ == "__main__":
    main()
