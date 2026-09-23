#!/usr/bin/env python3
"""
Approximate compiler spill/fill analyzer for the GEMM register-pressure sweep.

Method:
- Examine only the gemm4x4_i8 function body.
- Count stack-pointer/frame-pointer-relative LW/SW operations.
- Exclude a conservative prologue/epilogue window containing saved-register
  traffic where possible.
- Report both:
    raw_stack_loads/stores
    likely_spill_loads/stores

This is evidence from compiler-generated assembly. It does NOT insert any
spill/fill operations.

Caveat:
Stack-relative accesses are a practical proxy, not perfect ground truth.
Before publication, validate representative cases manually from assembly
and/or compiler RTL allocation dumps.
"""

import csv
import re
import sys
from pathlib import Path

build = Path(sys.argv[1] if len(sys.argv) > 1 else "build")

levels = ["full", "p1", "p2", "p3", "p4"]

# Matches lw/sw something, offset(sp) or offset(s0)
stack_mem = re.compile(
    r'^\s*(lw|sw)\s+[^,]+,\s*(-?\d+)\((sp|s0)\)',
    re.IGNORECASE
)

def extract_function(lines, fn="gemm4x4_i8"):
    start = None
    for i, line in enumerate(lines):
        if re.match(rf'^\s*{re.escape(fn)}:\s*$', line):
            start = i + 1
            break
    if start is None:
        return []

    body = []
    for line in lines[start:]:
        # next non-local symbol label ends the function
        if re.match(r'^[A-Za-z_.$][A-Za-z0-9_.$]*:\s*$', line):
            label = line.strip()[:-1]
            if not label.startswith(".L"):
                break
        body.append(line)
    return body

def classify(body):
    accesses = []
    for idx, line in enumerate(body):
        m = stack_mem.search(line)
        if m:
            accesses.append((idx, m.group(1).lower(), m.group(3).lower(), line.strip()))

    raw_loads = sum(1 for _,op,_,_ in accesses if op == "lw")
    raw_stores = sum(1 for _,op,_,_ in accesses if op == "sw")

    # Conservative heuristic:
    # saved-register stores tend to cluster at the start and restores at end.
    # Count stack accesses in the middle 80% as likely allocator spill/fill.
    n = len(body)
    lo = max(0, int(n * 0.10))
    hi = min(n, int(n * 0.90))

    likely = [a for a in accesses if lo <= a[0] < hi]
    likely_loads = sum(1 for _,op,_,_ in likely if op == "lw")
    likely_stores = sum(1 for _,op,_,_ in likely if op == "sw")

    return raw_loads, raw_stores, likely_loads, likely_stores, accesses, likely

rows = []

for lvl in levels:
    path = build / f"gemm_{lvl}.s"
    if not path.exists():
        continue

    lines = path.read_text(errors="ignore").splitlines()
    body = extract_function(lines)

    raw_l, raw_s, spill_l, spill_s, accesses, likely = classify(body)

    rows.append({
        "pressure_level": lvl,
        "function_lines": len(body),
        "raw_stack_loads": raw_l,
        "raw_stack_stores": raw_s,
        "likely_spill_fills": spill_l,
        "likely_spill_stores": spill_s,
        "likely_total_spill_events": spill_l + spill_s,
    })

    evidence = build / f"spill_evidence_{lvl}.txt"
    with evidence.open("w") as f:
        f.write(f"Register pressure level: {lvl}\n")
        f.write("All stack-relative lw/sw in function:\n\n")
        for idx, op, base, line in accesses:
            marker = "LIKELY-SPILL/FILL" if (idx,op,base,line) in likely else "PROLOGUE/EPILOGUE?"
            f.write(f"{marker:20s} line {idx:4d}: {line}\n")

out = build / "spill_summary.csv"
with out.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=[
        "pressure_level",
        "function_lines",
        "raw_stack_loads",
        "raw_stack_stores",
        "likely_spill_fills",
        "likely_spill_stores",
        "likely_total_spill_events",
    ])
    writer.writeheader()
    writer.writerows(rows)

print("\n--- SPILL SUMMARY ---")
print(f"{'level':8s} {'rawL':>6s} {'rawS':>6s} {'spillL':>7s} {'spillS':>7s} {'total':>7s}")
for r in rows:
    print(f"{r['pressure_level']:8s} "
          f"{r['raw_stack_loads']:6d} "
          f"{r['raw_stack_stores']:6d} "
          f"{r['likely_spill_fills']:7d} "
          f"{r['likely_spill_stores']:7d} "
          f"{r['likely_total_spill_events']:7d}")

print(f"\nWrote {out}")
print("Also wrote build/spill_evidence_<level>.txt for manual inspection.")
