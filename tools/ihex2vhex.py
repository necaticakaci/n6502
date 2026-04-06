#!/usr/bin/env python3
"""
ihex2vhex — Intel HEX to Verilog $readmemh converter

Converts Intel HEX (.hex, .ihex) files to flat hex format compatible
with Verilog's $readmemh system task. Supports 16-bit addressing
(record types 00 and 01).

Output: one hex byte per line, zero-padded to fill the address space.

Usage:
    python3 ihex2vhex.py input.hex -o output.vhex
    python3 ihex2vhex.py input.hex -o output.vhex -s 32768
    python3 ihex2vhex.py input.hex                          # prints to stdout
"""

import argparse
import sys

def parse_intel_hex(filename):
    """Parse an Intel HEX file and return a dict of {address: byte_value}."""
    data = {}
    with open(filename, "r") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            if line[0] != ":":
                print(f"Warning: skipping non-record line {line_num}: {line[:40]}",
                      file=sys.stderr)
                continue

            # Parse fields
            try:
                byte_count  = int(line[1:3], 16)
                address     = int(line[3:7], 16)
                record_type = int(line[7:9], 16)
                payload     = line[9:9 + byte_count * 2]
            except (ValueError, IndexError) as e:
                print(f"Error: malformed record at line {line_num}: {e}",
                      file=sys.stderr)
                sys.exit(1)

            # Verify checksum
            raw_bytes = bytes.fromhex(line[1:])
            if sum(raw_bytes) & 0xFF != 0:
                print(f"Warning: checksum mismatch at line {line_num}",
                      file=sys.stderr)

            if record_type == 0x00:  # Data record
                for i in range(byte_count):
                    val = int(payload[i * 2:i * 2 + 2], 16)
                    data[address + i] = val
            elif record_type == 0x01:  # End Of File
                break
            else:
                print(f"Warning: unsupported record type 0x{record_type:02X} "
                      f"at line {line_num}, skipping", file=sys.stderr)

    return data

def write_vhex(data, output, size, fill):
    """Write flat hex output (one byte per line) for $readmemh."""
    for addr in range(size):
        val = data.get(addr, fill)
        output.write(f"{val:02X}\n")

def main():
    parser = argparse.ArgumentParser(
        description="Convert Intel HEX to Verilog $readmemh format.",
        epilog="Example: python3 ihex2vhex.py firmware.hex -o firmware.vhex -s 65536",
    )
    parser.add_argument("input",
                        help="Input Intel HEX file (.hex, .ihex)")
    parser.add_argument("-o", "--output",
                        help="Output file (default: stdout)")
    parser.add_argument("-s", "--size", type=int, default=65536,
                        help="Memory size in bytes (default: 65536)")
    parser.add_argument("-f", "--fill", type=lambda x: int(x, 0), default=0x00,
                        help="Fill value for unused addresses (default: 0x00)")
    args = parser.parse_args()

    if args.size < 1 or args.size > 1048576:
        print("Error: size must be between 1 and 1048576 (1MB)", file=sys.stderr)
        sys.exit(1)

    data = parse_intel_hex(args.input)

    if not data:
        print("Warning: no data records found in input file", file=sys.stderr)

    # Report stats
    min_addr = min(data.keys()) if data else 0
    max_addr = max(data.keys()) if data else 0
    print(f"Parsed {len(data)} bytes, address range: "
          f"${min_addr:04X}-${max_addr:04X}", file=sys.stderr)

    if max_addr >= args.size:
        print(f"Warning: max address ${max_addr:04X} exceeds specified size "
              f"{args.size} (${args.size - 1:04X}), data will be truncated",
              file=sys.stderr)

    if args.output:
        with open(args.output, "w") as f:
            write_vhex(data, f, args.size, args.fill)
        print(f"Written {args.size} bytes to {args.output}", file=sys.stderr)
    else:
        write_vhex(data, sys.stdout, args.size, args.fill)

if __name__ == "__main__":
    main()
