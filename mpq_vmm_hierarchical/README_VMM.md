# Hierarchical INT2 / INT4 / INT8 4-Output VMM

This package extends the previously verified hierarchical MPQ dot-product
design into a four-output vector-matrix multiply block.

## Top module

`mpq_vmm4_hier.v`

Inputs:
- `activation[63:0]`
- `weight0[63:0]`
- `weight1[63:0]`
- `weight2[63:0]`
- `weight3[63:0]`
- `precision[1:0]`

Outputs:
- `out0[31:0]`
- `out1[31:0]`
- `out2[31:0]`
- `out3[31:0]`

Precision encoding:
- `00` = INT2
- `01` = INT4
- `10` = INT8
- `11` = reserved, outputs zero

Equivalent matrix operations:
- INT2: `(1 x 32) x (32 x 4)`
- INT4: `(1 x 16) x (16 x 4)`
- INT8: `(1 x 8)  x (8 x 4)`

## Compile

```bash
iverilog -g2012 -o sim_vmm \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_vmm4_hier.v tb_mpq_vmm4_hier.v
```

## Run

```bash
vvp sim_vmm
```

Expected ending:

```text
INT2 VMM randomized tests complete
INT4 VMM randomized tests complete
INT8 VMM randomized tests complete
Reserved-precision VMM test complete

ALL VMM TESTS PASSED
```

The randomized portion checks 100 vectors at each precision. Since each
vector produces four independently checked outputs, that is 1,200 random
dot-product output checks, plus directed/reserved checks.

## Waveform

```bash
gtkwave mpq_vmm4_hier.vcd
```
