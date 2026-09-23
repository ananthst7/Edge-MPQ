# PicoRV32 PCPI Mixed-Precision Dot Product — Standalone Wrapper

This stage verifies the custom instruction decoder and PCPI handshake
before connecting the design to the full PicoRV32 core.

## Instruction encoding

Uses RISC-V CUSTOM-0 opcode:

- opcode `0001011`
- funct3 `000` = packed INT2 dot
- funct3 `001` = packed INT4 dot
- funct3 `010` = packed INT8 dot

The remaining R-type fields can later map normally to `rd`, `rs1`, `rs2`.

## RV32 packed throughput

Because PicoRV32 registers are 32 bits:

- INT2 = 16 signed products per instruction
- INT4 = 8 signed products per instruction
- INT8 = 4 signed products per instruction

The existing verified 64-bit hierarchy is reused internally with zeroed
upper 32 bits.

## Compile

```bash
iverilog -g2012 -o sim_pcpi \
  umul2.v umul4_hier.v umul8_hier.v \
  smul2_hier.v smul4_hier.v smul8_hier.v \
  int2_dot_hier.v int4_dot_hier.v int8_dot_hier.v \
  mpq_dot_hier.v mpq_pcpi.v tb_mpq_pcpi.v
```

## Run

```bash
vvp sim_pcpi
```

Expected ending:

```text
INT2 PCPI randomized tests complete
INT4 PCPI randomized tests complete
INT8 PCPI randomized tests complete

ALL PCPI WRAPPER TESTS PASSED
```

## Waveform

```bash
gtkwave mpq_pcpi.vcd
```

## Important

This is only the standalone PCPI coprocessor wrapper. It verifies:
- custom instruction decode,
- precision selection,
- use of rs1/rs2,
- PCPI writeback,
- unsupported-instruction rejection.

The next stage connects these same signals to an actual PicoRV32 instance.
