#!/usr/bin/env python3
"""
Full-system event-count energy model for the MPQ PicoRV32 project.

E_total = E_compute + E_RF + E_memory + E_packing

This script intentionally refuses to invent physical energy constants.
Populate energy_constants.csv with pJ/event values obtained from synthesis,
activity-based power analysis, SRAM/RF characterization, or a clearly cited
reference before claiming absolute energy numbers.
"""

import csv
import math
from pathlib import Path

EVENTS_FILE = Path("events.csv")
CONSTANTS_FILE = Path("energy_constants.csv")
OUT_FILE = Path("energy_breakdown.csv")

REQUIRED_CONSTANTS = [
    "int2_dot",
    "int4_dot",
    "int8_dot",
    "rf_read",
    "rf_write",
    "dmem_read",
    "dmem_write",
    "packing_op",
]

def read_single_row_csv(path):
    with path.open(newline="") as f:
        rows = list(csv.DictReader(f))
    if len(rows) != 1:
        raise RuntimeError(f"{path} must contain exactly one data row.")
    return rows[0]

def read_constants(path):
    values = {}
    with path.open(newline="") as f:
        for row in csv.DictReader(f):
            name = row["parameter"].strip()
            raw = row["value_pJ"].strip()
            values[name] = None if raw == "" else float(raw)
    return values

events = read_single_row_csv(EVENTS_FILE)
events = {k: int(v) for k, v in events.items()}

constants = read_constants(CONSTANTS_FILE)

missing = [
    name for name in REQUIRED_CONSTANTS
    if name not in constants or constants[name] is None
]

print("--- MPQ ENERGY MODEL INPUT EVENTS ---")
for k, v in events.items():
    print(f"{k:22s}: {v}")

if missing:
    print("\nEnergy event-count pipeline is working, but absolute energy is NOT")
    print("computed because these physical coefficients are still missing:")
    for name in missing:
        print(f"  - {name}")
    print("\nPopulate energy_constants.csv with pJ/event values and rerun:")
    print("  python3 energy_model.py")
    raise SystemExit(2)

e_compute = (
    events["custom_int2"] * constants["int2_dot"]
    + events["custom_int4"] * constants["int4_dot"]
    + events["custom_int8"] * constants["int8_dot"]
)

e_rf = (
    events["arch_rf_reads"] * constants["rf_read"]
    + events["arch_rf_writes"] * constants["rf_write"]
)

e_memory = (
    events["dmem_reads"] * constants["dmem_read"]
    + events["dmem_writes"] * constants["dmem_write"]
)

e_packing = events["packing_ops"] * constants["packing_op"]

e_total = e_compute + e_rf + e_memory + e_packing

rows = [
    ("compute", e_compute),
    ("register_file", e_rf),
    ("memory", e_memory),
    ("packing", e_packing),
    ("total", e_total),
]

with OUT_FILE.open("w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["component", "energy_pJ", "share_percent"])
    for name, value in rows:
        share = 100.0 * value / e_total if e_total else 0.0
        w.writerow([name, f"{value:.6f}", f"{share:.6f}"])

print("\n--- ENERGY BREAKDOWN ---")
for name, value in rows:
    if name == "total":
        print(f"{name:14s}: {value:.6f} pJ")
    else:
        share = 100.0 * value / e_total if e_total else 0.0
        print(f"{name:14s}: {value:.6f} pJ ({share:.2f}%)")

print(f"\nWrote {OUT_FILE}")
