#!/usr/bin/env bash
set -euo pipefail

echo "=== Building firmware ==="
CC="${CC:-riscv64-unknown-elf-gcc}" \
OBJCOPY="${OBJCOPY:-riscv64-unknown-elf-objcopy}" \
OBJDUMP="${OBJDUMP:-riscv64-unknown-elf-objdump}" \
./build_firmware.sh

echo
echo "=== Building RTL simulator ==="
iverilog -g2012 -o sim_full_energy \
  ../picorv32/picorv32.v \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_pcpi.v picorv32_mpq_top.v \
  tb_full_energy_pipeline.v

for lvl in full p2 p4; do
  echo
  echo "=== SIM $lvl ==="
  vvp sim_full_energy \
    +firmware=build/fw_${lvl}.hex \
    +events=events_${lvl}.csv
done

echo
echo "Generated:"
ls -lh events_*.csv
echo
python3 summarize_events.py
