#!/usr/bin/env python3
"""Convert raw binary to Verilog $readmemh format (32-bit little-endian words)."""
import sys

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.bin output.hex")
        sys.exit(1)

    with open(sys.argv[1], 'rb') as f:
        data = f.read()

    # Pad to 4-byte boundary
    while len(data) % 4:
        data += b'\x00'

    with open(sys.argv[2], 'w') as f:
        for i in range(0, len(data), 4):
            word = int.from_bytes(data[i:i+4], 'little')
            f.write(f'{word:08X}\n')

    print(f"Generated {sys.argv[2]}: {len(data)//4} words ({len(data)} bytes)")

if __name__ == '__main__':
    main()
