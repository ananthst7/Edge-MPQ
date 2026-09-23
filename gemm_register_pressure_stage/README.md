# Stage: GEMM Register-Pressure / Organic Spill Experiment

This is the next stage after the working PicoRV32 + MPQ energy-event pipeline.

## Objective

Generate **compiler-induced** spill/fill traffic naturally.

No `lw`/`sw` spill instructions are inserted by us.

Instead:

1. A GEMM-style kernel keeps 16 accumulators live.
2. GCC performs normal register allocation.
3. We progressively reserve RISC-V registers with `-ffixed-...`.
4. Register pressure rises.
5. If the allocator runs out of usable registers, GCC emits stack spills/fills.
6. The generated assembly is analyzed and preserved as evidence.

This directly supports the project's controlled GPR/register-pressure axis.

## Files

- `gemm4x4_i8.c` — real 4x4 INT8 GEMM microkernel
- `build_sweep.sh` — compiles it under several register-pressure levels
- `analyze_spills.py` — analyzes compiler-generated stack traffic

## Toolchain

Check first:

```bash
riscv32-unknown-elf-gcc --version
```

If your compiler has a different name, e.g. `riscv64-unknown-elf-gcc`,
you can normally still target RV32:

```bash
CC=riscv64-unknown-elf-gcc \
OBJDUMP=riscv64-unknown-elf-objdump \
./build_sweep.sh
```

## Run

```bash
chmod +x build_sweep.sh
./build_sweep.sh
```

Outputs include:

```text
build/
├── gemm_full.s
├── gemm_p1.s
├── gemm_p2.s
├── gemm_p3.s
├── gemm_p4.s
├── spill_summary.csv
├── spill_evidence_full.txt
├── ...
└── spill_evidence_p4.txt
```

## What to expect

Do NOT expect a predetermined number of spills.

The valid result may be:

- no spills at low pressure,
- increasing spills at higher pressure,
- or a nonlinear pattern depending on GCC's allocator.

That behavior is the experiment.

## Important caveat

`analyze_spills.py` uses stack-relative `lw/sw` traffic as a practical
spill/fill proxy and conservatively excludes the outer 10% of the function
to reduce contamination from prologue/epilogue register saves/restores.

For the review, show:
1. the compiler command,
2. assembly excerpts,
3. spill evidence files,
4. `spill_summary.csv`.

Before treating the counts as publication-grade ground truth, manually
inspect representative assembly and refine the classifier if necessary.

## Next after this

Once organic spills are confirmed, the next stage is to execute selected
compiled kernels on PicoRV32 and feed measured:

- cycles,
- RF accesses,
- memory traffic,
- spill/fill events,
- packing operations

into the already-built energy model.
