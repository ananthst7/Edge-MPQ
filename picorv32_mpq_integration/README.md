# PicoRV32 + Hierarchical MPQ PCPI Integration

This stage connects the verified custom mixed-precision PCPI coprocessor
to an unmodified PicoRV32 core.

## Directory requirement

You already have:

```text
~/Documents/fyp/v1/picorv32/picorv32.v
```

Keep the integration folder alongside it:

```text
~/Documents/fyp/v1/
├── picorv32/
└── picorv32_mpq_integration/
```

## What the firmware does

It creates:

```text
x1 = 0x04030201   -> signed INT8 lanes [1,2,3,4]
x2 = 0x01020304   -> signed INT8 lanes [4,3,2,1]
```

Then executes the custom instruction:

```text
DOT8 x3, x1, x2
```

Mathematically:

```text
x3 = 1*4 + 2*3 + 3*2 + 4*1
   = 20
```

The firmware then executes:

```text
sw x3, 0x100(x0)
```

The testbench watches address `0x100` and passes only if the stored result
is exactly 20.

## Compile

From `~/Documents/fyp/v1/picorv32_mpq_integration`:

```bash
iverilog -g2012 -o sim_cpu \
  ../picorv32/picorv32.v \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_pcpi.v \
  picorv32_mpq_top.v tb_picorv32_mpq.v
```

## Run

```bash
vvp sim_cpu
```

Expected output contains:

```text
RESULT WRITE: addr=00000100 data=20 ...
PICORV32 + MPQ PCPI DOT8 TEST PASSED
```

## Waveform

```bash
gtkwave picorv32_mpq.vcd
```

Useful signals to inspect:
- `pcpi_valid`
- `pcpi_insn`
- `pcpi_rs1`
- `pcpi_rs2`
- `pcpi_ready`
- `pcpi_wr`
- `pcpi_rd`
- `mem_addr`
- `mem_wdata`
- `mem_wstrb`

## Why only DOT8 first?

This is deliberately the smallest full CPU integration test. Once it
passes, the same firmware/test structure can be extended to DOT2 and DOT4,
and then to cycle comparisons against software implementations.
