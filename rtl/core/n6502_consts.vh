// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Shared Definitions
// ******************************************************

`ifndef N6502_CONSTS_VH
`define N6502_CONSTS_VH

// Addressing Mode Codes
`define AM_IMP   4'h0   // Implied
`define AM_ACC   4'h1   // Accumulator
`define AM_IMM   4'h2   // Immediate
`define AM_ZP    4'h3   // Zero Page
`define AM_ZPX   4'h4   // Zero Page,X
`define AM_ZPY   4'h5   // Zero Page,Y
`define AM_ABS   4'h6   // Absolute
`define AM_ABX   4'h7   // Absolute,X
`define AM_ABY   4'h8   // Absolute,Y
`define AM_IND   4'h9   // Indirect (JMP only)
`define AM_IZX   4'hA   // (Indirect,X)
`define AM_IZY   4'hB   // (Indirect),Y
`define AM_REL   4'hC   // Relative (branches)
`define AM_NONE  4'hF   // Invalid

// ALU Operation Codes
`define ALU_ADC  4'h0   // A + B + C
`define ALU_SBC  4'h1   // A - B - !C
`define ALU_AND  4'h2   // A & B
`define ALU_ORA  4'h3   // A | B
`define ALU_EOR  4'h4   // A ^ B
`define ALU_ASL  4'h5   // B << 1
`define ALU_LSR  4'h6   // B >> 1
`define ALU_ROL  4'h7   // {B[6:0], C}
`define ALU_ROR  4'h8   // {C, B[7:1]}
`define ALU_INC  4'h9   // B + 1
`define ALU_DEC  4'hA   // B - 1
`define ALU_CMP  4'hB   // A - B (flags only)
`define ALU_BIT  4'hC   // Test bits
`define ALU_PASS 4'hD   // Passthrough B

// Register Codes
`define REG_A    3'h0   // Accumulator
`define REG_X    3'h1   // X register
`define REG_Y    3'h2   // Y register
`define REG_SP   3'h3   // Stack Pointer
`define REG_P    3'h4   // Processor Status
`define REG_MEM  3'h5   // Memory operand
`define REG_NONE 3'h7   // No register

// Flag Bit Positions in P register (NV-BDIZC)
`define FLAG_N   7      // Negative
`define FLAG_V   6      // Overflow
`define FLAG_B   4      // Break (virtual)
`define FLAG_D   3      // Decimal
`define FLAG_I   2      // Interrupt Disable
`define FLAG_Z   1      // Zero
`define FLAG_C   0      // Carry

// Flag Masks
`define FMASK_N    8'b1000_0000
`define FMASK_V    8'b0100_0000
`define FMASK_B    8'b0001_0000
`define FMASK_D    8'b0000_1000
`define FMASK_I    8'b0000_0100
`define FMASK_Z    8'b0000_0010
`define FMASK_C    8'b0000_0001

`define FMASK_NZ   (`FMASK_N | `FMASK_Z)
`define FMASK_NZC  (`FMASK_N | `FMASK_Z | `FMASK_C)
`define FMASK_NVZC (`FMASK_N | `FMASK_V | `FMASK_Z | `FMASK_C)
`define FMASK_NVZ  (`FMASK_N | `FMASK_V | `FMASK_Z)

`endif // N6502_CONSTS_VH
