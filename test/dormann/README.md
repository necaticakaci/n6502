# Klaus Dormann 6502 Functional Tests

This directory contains a pre-built binary of the
Klaus Dormann 6502 Functional Tests.

## Source

- **Repository:** https://github.com/Klaus2m5/6502_65C02_functional_tests
- **Author:** Klaus Dormann
- **License:** GNU General Public License v3.0

## Notes

- Only the NMOS 6502 functional test (`6502_functional_test`) is included.
  The 65C02, interrupt, and BCD decimal tests are not used by this project.
- The test ROM expects execution to start at `$0400`. The n6502 testbench
  overrides the reset vector (`$FFFC/$FFFD`) to point there.
- A successful run ends with the CPU reaching PC = `$336D` (self-loop trap
  at the end of all tests).
- The `.vhex` file is a flat 65536-byte hex dump - one byte per line,
  addresses `$0000`–`$FFFF`.

## Regenerating

To regenerate the `.vhex` file from the upstream Intel HEX file, use the
`ihex2vhex` tool included in this repository:

```bash
# From the project root:
python3 tools/ihex2vhex.py 6502_functional_test.hex -o test/dormann/6502_functional_test.vhex -s 65536
```

The original `.hex` file can be assembled from the upstream repository using
the `as65` assembler included there.

See `tools/ihex2vhex.py --help` for all options:

```
usage: ihex2vhex.py [-h] [-o OUTPUT] [-s SIZE] [-f FILL] input

Convert Intel HEX to Verilog $readmemh format.

positional arguments:
  input                 Input Intel HEX file (.hex, .ihex)

options:
  -o, --output OUTPUT   Output file (default: stdout)
  -s, --size SIZE       Memory size in bytes (default: 65536)
  -f, --fill FILL       Fill value for unused addresses (default: 0x00)
```
