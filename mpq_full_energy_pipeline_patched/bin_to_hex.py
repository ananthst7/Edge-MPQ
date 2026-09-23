#!/usr/bin/env python3
import sys
from pathlib import Path

if len(sys.argv) != 3:
    print("usage: bin_to_hex.py input.bin output.hex")
    raise SystemExit(1)

data = Path(sys.argv[1]).read_bytes()
if len(data) % 4:
    data += bytes(4 - (len(data) % 4))

with Path(sys.argv[2]).open("w") as f:
    for i in range(0, len(data), 4):
        w = int.from_bytes(data[i:i+4], "little")
        f.write(f"{w:08x}\n")
