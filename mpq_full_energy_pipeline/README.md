# Full Dynamic Energy-Event Pipeline

This stage closes the **event-counting side** of:

`E_total = E_compute + E_RF + E_memory + E_packing`

using code that actually runs on PicoRV32.

## What is natural/measured

The firmware performs all of these at runtime:

1. Packs source values into INT2, INT4 and INT8 words.
2. Executes the real `DOT2`, `DOT4`, `DOT8` custom PCPI instructions.
3. Executes a pressure-heavy GEMM kernel.
4. The same firmware is compiled at `full`, `p2`, and `p4` register-pressure levels.
5. PicoRV32's memory bus is observed dynamically.

No spill/fill instructions or result counts are scripted into the RTL.

## Runtime counters

The simulation produces:

- cycles
- architectural RF reads/writes
- normal data-memory reads/writes
- custom INT2/4/8 operations
- dynamic packing ALU operations
- loads/stores occurring during packing
- dynamic stack loads/stores while GEMM is executing

Stack traffic is detected from real PicoRV32 memory addresses in the region
below the configured stack pointer (`SP = 0x1F000`).

## Folder layout

Keep this folder beside:

```text
~/Documents/fyp/v1/picorv32/
```

## Run everything

```bash
cd ~/Documents/fyp/v1/mpq_full_energy_pipeline
chmod +x build_firmware.sh run_all.sh
./run_all.sh
```

This should generate:

```text
build/fw_full.hex
build/fw_p2.hex
build/fw_p4.hex

events_full.csv
events_p2.csv
events_p4.csv

dynamic_event_summary.csv
```

## Expected behavior

There is NO hard-coded expected spill count.

The experiment is valid whether the dynamic stack traffic rises smoothly,
jumps, or behaves non-linearly. The generated assembly and PicoRV32 bus
activity determine the result.

## Energy equation

`energy_model.py` computes:

```text
Ecompute = Ndot2*Edot2 + Ndot4*Edot4 + Ndot8*Edot8

ERF = Nrf_read*Erf_read + Nrf_write*Erf_write

Ememory = Nmem_read*Emem_read + Nmem_write*Emem_write

Epacking = Npacking_ALU*Epacking_ALU

Etotal = Ecompute + ERF + Ememory + Epacking
```

The coefficient CSV is intentionally blank.

Do not claim absolute pJ values until those coefficients are populated from
synthesis/activity measurements or clearly cited characterization data.

## Important accounting rule

Packing loads/stores are already part of the memory term. Therefore
`Epacking` counts only non-memory ALU operations executed in the packing
region. This avoids double-counting energy.

## Run the energy model

After populating `energy_constants.csv`:

```bash
python3 energy_model.py events_full.csv
python3 energy_model.py events_p2.csv
python3 energy_model.py events_p4.csv
```

At that point the four-component energy decomposition is numerically
complete.
