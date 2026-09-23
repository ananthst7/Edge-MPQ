#!/usr/bin/env bash
set -euo pipefail

CC="${CC:-riscv32-unknown-elf-gcc}"
OBJDUMP="${OBJDUMP:-riscv32-unknown-elf-objdump}"

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "ERROR: $CC not found."
  echo "Install/use a RISC-V GCC toolchain, or run with:"
  echo "  CC=<your-gcc> OBJDUMP=<your-objdump> ./build_sweep.sh"
  exit 1
fi

mkdir -p build

COMMON=(
  -O2
  -march=rv32im
  -mabi=ilp32
  -ffreestanding
  -fno-builtin
  -fno-omit-frame-pointer
  -fno-inline
  -Wall
  -Wextra
)

# We reserve caller-saved temporaries progressively.
# This does NOT add spill instructions manually; it merely tells GCC
# those registers are unavailable, forcing the normal allocator to cope.
#
# The labels are "pressure levels", not literal physical GPR counts.

declare -A FIXED
FIXED[full]=""
FIXED[p1]="-ffixed-t6 -ffixed-t5 -ffixed-t4"
FIXED[p2]="-ffixed-t6 -ffixed-t5 -ffixed-t4 -ffixed-t3 -ffixed-t2 -ffixed-t1"
FIXED[p3]="-ffixed-t6 -ffixed-t5 -ffixed-t4 -ffixed-t3 -ffixed-t2 -ffixed-t1 -ffixed-t0 -ffixed-a7 -ffixed-a6"
FIXED[p4]="-ffixed-t6 -ffixed-t5 -ffixed-t4 -ffixed-t3 -ffixed-t2 -ffixed-t1 -ffixed-t0 -ffixed-a7 -ffixed-a6 -ffixed-a5 -ffixed-a4 -ffixed-a3"

for lvl in full p1 p2 p3 p4; do
  echo "=== Building $lvl ==="
  # shellcheck disable=SC2086
  "$CC" "${COMMON[@]}" ${FIXED[$lvl]} \
    -S gemm4x4_i8.c -o "build/gemm_${lvl}.s"

  # Also produce an object and disassembly.
  # shellcheck disable=SC2086
  "$CC" "${COMMON[@]}" ${FIXED[$lvl]} \
    -c gemm4x4_i8.c -o "build/gemm_${lvl}.o"

  "$OBJDUMP" -d -M no-aliases "build/gemm_${lvl}.o" \
    > "build/gemm_${lvl}.objdump"
done

python3 analyze_spills.py build

echo
echo "Done. Inspect:"
echo "  build/spill_summary.csv"
echo "  build/gemm_<level>.s"
