#!/usr/bin/env bash
set -euo pipefail

CC="${CC:-riscv64-unknown-elf-gcc}"
OBJCOPY="${OBJCOPY:-riscv64-unknown-elf-objcopy}"
OBJDUMP="${OBJDUMP:-riscv64-unknown-elf-objdump}"

mkdir -p build

COMMON=(
  -O2
  -march=rv32im
  -mabi=ilp32
  -ffreestanding
  -nostdlib
  -fno-builtin
  -fno-inline
  -fno-omit-frame-pointer
  -Wall
  -Wextra
  -Wl,-T,linker.ld
  -Wl,--no-relax
)

declare -A FIXED
FIXED[full]=""
FIXED[p2]="-ffixed-t6 -ffixed-t5 -ffixed-t4 -ffixed-t3 -ffixed-t2 -ffixed-t1"
FIXED[p4]="-ffixed-t6 -ffixed-t5 -ffixed-t4 -ffixed-t3 -ffixed-t2 -ffixed-t1 -ffixed-t0 -ffixed-a7 -ffixed-a6 -ffixed-a5 -ffixed-a4 -ffixed-a3"

for lvl in full p2 p4; do
  echo "=== BUILD $lvl ==="
  # shellcheck disable=SC2086
  "$CC" "${COMMON[@]}" ${FIXED[$lvl]} \
    crt0.S benchmark.c -o "build/fw_${lvl}.elf"

  "$OBJCOPY" -O binary "build/fw_${lvl}.elf" "build/fw_${lvl}.bin"
  python3 bin_to_hex.py "build/fw_${lvl}.bin" "build/fw_${lvl}.hex"

  "$OBJDUMP" -d -M no-aliases "build/fw_${lvl}.elf" \
    > "build/fw_${lvl}.objdump"
done

echo
echo "Firmware generated:"
ls -lh build/fw_*.hex
