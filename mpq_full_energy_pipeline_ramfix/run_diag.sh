#!/usr/bin/env bash
set -euo pipefail

CC="${CC:-riscv64-unknown-elf-gcc}" \
OBJCOPY="${OBJCOPY:-riscv64-unknown-elf-objcopy}" \
OBJDUMP="${OBJDUMP:-riscv64-unknown-elf-objdump}" \
./build_firmware.sh

iverilog -g2012 -o sim_diag \
  ../picorv32/picorv32.v \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_pcpi.v picorv32_mpq_top.v \
  tb_full_energy_pipeline.v

echo
echo "=== DIAGNOSTIC SIM: full ==="
vvp sim_diag +firmware=build/fw_full.hex +events=events_diag_full.csv
