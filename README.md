# n6502

A small, FPGA optimized 6502 compatible CPU core written in Verilog-2005.

## Limitations

- **No pin compatibility** — Core uses a generic bus interface that is not compatible with the original 6502 pin layout.
- **No cycle accuracy** — Instruction timing differs from the original NMOS 6502. The n6502 is generally faster due to overlap fetch and pre-launch patterns. Not suitable for cycle-exact emulation.
- **No BCD mode** — ADC/SBC in decimal mode behave as binary.
- **No illegal opcodes** — Only the 151 legal 6502 opcodes are implemented. An illegal opcode halts the core and asserts the `dbg_illegal` debug output until reset.

## Directory Structure

```
n6502/
├── rtl/
│   ├── core/                   CPU core RTL source files
│   └── soc/                    SoC RTL source files
├── sim/                        Testbenches
│   ├── tb_n6502_alu.v          ALU unit tests
│   ├── tb_n6502_decoder.v      Decoder unit tests
│   ├── tb_n6502_core.v         Core functional tests
│   ├── tb_n6502_irq.v          Interrupt (IRQ/NMI) tests
│   ├── tb_n6502_dormann.v      Klaus Dormann testbench
│   └── tb_n6502_soc.v          SoC testbench
├── test/
│   ├── dormann/                Dormann test ROM
│   └── programs/               Example programs
├── tools/
│   └── ihex2vhex.py            Intel HEX to Verilog $readmemh converter
├── LICENSE                     License file
├── Makefile                    Build & simulation targets
└── README.md                   This file
```

## Quick Start

### Prerequisites

- Icarus Verilog
- Verilator (Lint only)

### Run Tests

```bash
# Unit tests
make sim_alu
make sim_decoder

# Core functional test
make sim_core

# Interrupt (IRQ/NMI) test, zero-wait and 1-wait-state memory
make sim_irq

# Klaus Dormann test suite (takes ~20-25 minutes)
make sim_dormann

# System on Chip test
make sim_soc
```

## Bus Interface

| Signal | Direction | Description |
|---|---|---|
| `bus_addr[15:0]` | Master -> Slave | Address bus |
| `bus_wdata[7:0]` | Master -> Slave | Write data |
| `bus_rdata[7:0]` | Slave -> Master | Read data |
| `bus_we` | Master -> Slave | Write enable (1 = write, 0 = read) |
| `bus_stb` | Master -> Slave | Strobe |
| `bus_ack` | Slave -> Master | Acknowledge |

For zero-wait-state memory, simply tie `bus_ack = bus_stb`. For slower peripherals, hold `bus_ack` low until the transfer is complete, then the CPU will stall.

## License

Licensed under the [Solderpad Hardware License v2.1](https://solderpad.org/licenses/SHL-2.1/).
