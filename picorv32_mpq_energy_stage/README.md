# PicoRV32 MPQ — INT2/4/8 + Event Counting + Energy-Model Skeleton

This stage closes the custom-instruction verification across all three
precisions and creates the first simulation-to-energy-analysis pipeline.

## What it executes

The firmware constructs:

- `x1 = 0x04030201`
- `x2 = 0x01020304`

and executes:

- `DOT2 x3,x1,x2` -> expected `4`
- `DOT4 x4,x1,x2` -> expected `20`
- `DOT8 x5,x1,x2` -> expected `20`

It then stores the results at:

- `0x100`
- `0x104`
- `0x108`

## Compile

Keep this directory beside your downloaded `picorv32/` folder.

```bash
iverilog -g2012 -o sim_energy_stage \
  ../picorv32/picorv32.v \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_pcpi.v \
  picorv32_mpq_top.v tb_picorv32_mpq_energy_stage.v
```

## Run

```bash
vvp sim_energy_stage
```

Expected ending:

```text
DOT2 RESULT: 4 ...
DOT4 RESULT: 20 ...
DOT8 RESULT: 20 ...

ALL PICORV32 INT2/INT4/INT8 TESTS PASSED
```

The simulation also creates:

```text
events.csv
picorv32_mpq_energy_stage.vcd
```

## Event counters currently produced

- total cycles
- instruction fetches
- data-memory reads
- data-memory writes
- completed INT2 PCPI operations
- completed INT4 PCPI operations
- completed INT8 PCPI operations
- architectural RF reads
- architectural RF writes
- packing operations

### RF-count caveat

The RF values are **architectural operand-access estimates derived from
executed instruction semantics**, not transistor-level/internal RF toggle
counts. This distinction must be preserved in the report.

### Packing-count caveat

This micro-test uses already-packed constants, therefore runtime
`packing_ops = 0`.

Packing/unpacking must become non-zero when we introduce real software
kernel preparation (shift/mask/pack/unpack code). Do not interpret zero
here as "packing has zero energy in general."

## Energy model

Run:

```bash
python3 energy_model.py
```

At first it will intentionally stop and list missing energy coefficients.

Populate:

```text
energy_constants.csv
```

with actual pJ/event values from measured/synthesized/cited sources.

Then rerun:

```bash
python3 energy_model.py
```

It computes:

```text
E_total = E_compute + E_RF + E_memory + E_packing
```

and writes:

```text
energy_breakdown.csv
```

## Next project step

The next major coding step is real software kernels and constrained-register
experiments, because that is what generates:

- real packing/unpacking events
- spill/fill loads and stores
- precision-dependent memory traffic

Those measured events will replace the simple micro-test counts in this
same energy-model pipeline.
