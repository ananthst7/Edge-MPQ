#!/usr/bin/env python3
import argparse, csv
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("events", help="events_full.csv / events_p2.csv / events_p4.csv")
ap.add_argument("--constants", default="energy_constants.csv")
args = ap.parse_args()

with Path(args.events).open() as f:
    ev = next(csv.DictReader(f))
ev = {k:int(v) for k,v in ev.items()}

co = {}
with Path(args.constants).open() as f:
    for r in csv.DictReader(f):
        raw = r["value_pJ"].strip()
        co[r["parameter"]] = None if not raw else float(raw)

required = [
    "int2_dot","int4_dot","int8_dot",
    "rf_read","rf_write",
    "dmem_read","dmem_write",
    "packing_alu_op"
]
missing = [x for x in required if co.get(x) is None]

print(f"Events: {args.events}")
print(f"  compute custom ops 2/4/8 = {ev['custom_int2']}/{ev['custom_int4']}/{ev['custom_int8']}")
print(f"  RF read/write            = {ev['rf_reads']}/{ev['rf_writes']}")
print(f"  memory read/write        = {ev['dmem_reads']}/{ev['dmem_writes']}")
print(f"  packing ALU ops          = {ev['packing_alu_ops']}")
print(f"  GEMM stack read/write    = {ev['gemm_stack_loads']}/{ev['gemm_stack_stores']}")

if missing:
    print("\nDynamic counts are complete, but absolute pJ cannot be claimed yet.")
    print("Missing physical coefficients:")
    for m in missing:
        print(" -", m)
    raise SystemExit(2)

e_compute = (
    ev["custom_int2"]*co["int2_dot"] +
    ev["custom_int4"]*co["int4_dot"] +
    ev["custom_int8"]*co["int8_dot"]
)
e_rf = ev["rf_reads"]*co["rf_read"] + ev["rf_writes"]*co["rf_write"]
e_mem = ev["dmem_reads"]*co["dmem_read"] + ev["dmem_writes"]*co["dmem_write"]
e_pack = ev["packing_alu_ops"]*co["packing_alu_op"]
e_total = e_compute + e_rf + e_mem + e_pack

print("\n--- ENERGY BREAKDOWN ---")
for n,v in [
    ("compute",e_compute),("RF",e_rf),
    ("memory",e_mem),("packing",e_pack),("TOTAL",e_total)
]:
    pct = 100*v/e_total if e_total else 0
    print(f"{n:8s} {v:12.4f} pJ  {pct:6.2f}%")
