#!/usr/bin/env python3
import csv
from pathlib import Path

rows = []
for lvl in ["full", "p2", "p4"]:
    p = Path(f"events_{lvl}.csv")
    if not p.exists():
        continue
    with p.open() as f:
        r = next(csv.DictReader(f))
    r["pressure_level"] = lvl
    rows.append(r)

cols = [
    "pressure_level","total_cycles",
    "rf_reads","rf_writes",
    "dmem_reads","dmem_writes",
    "packing_alu_ops","packing_loads","packing_stores",
    "all_stack_loads","all_stack_stores",
    "gemm_stack_loads","gemm_stack_stores",
    "gemm_marker_starts","gemm_marker_ends",
    "custom_int2","custom_int4","custom_int8"
]

with Path("dynamic_event_summary.csv").open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader()
    for r in rows:
        w.writerow({c:r.get(c,"") for c in cols})

print("\n--- DYNAMIC EVENT SUMMARY ---")
for r in rows:
    print(
        f"{r['pressure_level']:4s} "
        f"cycles={r['total_cycles']:>7s} "
        f"RF={r['rf_reads']}/{r['rf_writes']} "
        f"mem={r['dmem_reads']}/{r['dmem_writes']} "
        f"packALU={r['packing_alu_ops']} "
        f"allStack={r.get('all_stack_loads','?')}/{r.get('all_stack_stores','?')} "
        f"gemmStack={r.get('gemm_stack_loads','?')}/{r.get('gemm_stack_stores','?')} "
        f"markers={r.get('gemm_marker_starts','?')}/{r.get('gemm_marker_ends','?')}"
    )
print("\nWrote dynamic_event_summary.csv")
