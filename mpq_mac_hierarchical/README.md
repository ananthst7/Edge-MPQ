# Hierarchical INT2/INT4/INT8 MPQ MAC — Version 2

This version constructs wider multipliers explicitly from 2-bit unsigned leaf multipliers:

- `umul2.v` — 2-bit leaf multiplier, no `*` operator
- `umul4_hier.v` — 4-bit unsigned multiplier from 4 × `umul2`
- `umul8_hier.v` — 8-bit unsigned multiplier from 4 × `umul4_hier`
- `smul*_hier.v` — signed two's-complement wrappers using correction terms
- `int*_dot_hier.v` — packed 64-bit dot products
- `mpq_dot_hier.v` — precision selector
- `mpq_mac_hier.v` — dot + accumulator
- `tb_mpq_mac_hier.v` — directed + 100 randomized vectors per precision

Precision encoding:
- `00` INT2 (32 lanes per 64-bit word)
- `01` INT4 (16 lanes)
- `10` INT8 (8 lanes)
- `11` reserved, result = 0

Compile:

```bash
iverilog -g2012 -o sim_hier \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_mac_hier.v tb_mpq_mac_hier.v
vvp sim_hier
```

Waveform:

```bash
gtkwave mpq_mac_hier.vcd
```

Expected final line:

`ALL HIERARCHICAL TESTS PASSED`

Important: this is a structurally hierarchical functional RTL version. Do not claim area/power improvement over V1 until both are synthesized under the same tool, target, constraints, and optimization settings.
