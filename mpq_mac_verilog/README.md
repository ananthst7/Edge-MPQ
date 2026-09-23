# INT2/INT4/INT8 Mixed-Precision MAC — Functional Baseline

This is the first functional RTL baseline for the project.

## Modules

- `int2_dot.v` — 32 signed INT2 multiplies packed into two 64-bit operands
- `int4_dot.v` — 16 signed INT4 multiplies packed into two 64-bit operands
- `int8_dot.v` — 8 signed INT8 multiplies packed into two 64-bit operands
- `mpq_dot.v` — precision-selectable wrapper
- `mpq_mac.v` — adds a signed 32-bit accumulator input
- `tb_mpq_mac.v` — self-checking testbench + VCD dump

## Precision encoding

- `2'b00` = INT2
- `2'b01` = INT4
- `2'b10` = INT8
- `2'b11` = reserved/unsupported

## Icarus Verilog

```bash
iverilog -g2005-sv -o sim \
  int2_dot.v int4_dot.v int8_dot.v mpq_dot.v mpq_mac.v tb_mpq_mac.v
vvp sim
```

Expected end of output:

```text
ALL TESTS PASSED
```

A waveform file named `mpq_mac.vcd` is generated.

## GTKWave

```bash
gtkwave mpq_mac.vcd
```

## Important

This version prioritizes correctness and synthesizability. It instantiates separate INT2,
INT4 and INT8 datapaths and multiplexes the result. It is *not yet* the final optimized
hierarchical multiplier architecture. Once this baseline passes simulation and synthesis,
we can implement a shared/hierarchical version and compare LUT/area/power/timing.
