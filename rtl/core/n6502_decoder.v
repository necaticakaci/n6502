// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Instruction Decoder
//
// Illegal/undocumented opcodes are flagged via the 
// illegal output. BCD mode is not supported; SED/CLD
// only affect the D flag in P register.
// ******************************************************

`include "n6502_consts.vh"

module n6502_decoder (
   input  wire [7:0] opcode,

   // Decoded Control Signals
   output reg  [3:0] addr_mode,  // addressing mode
   output reg  [3:0] alu_op,     // ALU operation code
   output reg  [2:0] alu_src_a,  // ALU operand A source register
   output reg  [2:0] reg_src,    // source register (B operand / store)
   output reg  [2:0] reg_dst,    // destination register
   output reg        mem_read,   // instruction reads from memory
   output reg        mem_write,  // instruction writes to memory
   output reg  [7:0] flag_mask,  // which flags to update (NV-BDIZC)
   output reg        is_branch,  // branch instruction
   output reg        is_stack,   // stack operation (PHA/PLA/PHP/PLP)
   output reg        is_jump,    // JMP instruction
   output reg        is_jsr,     // JSR instruction
   output reg        is_return,  // RTS/RTI
   output reg        is_brk,     // BRK instruction
   output reg        illegal     // illegal opcode
);

   // Opcode Decode Logic
   always @(*) begin
      addr_mode  = `AM_NONE;
      alu_op     = `ALU_PASS;
      alu_src_a  = `REG_A;
      reg_src    = `REG_NONE;
      reg_dst    = `REG_NONE;
      mem_read   = 1'b0;
      mem_write  = 1'b0;
      flag_mask  = 8'h00;
      is_branch  = 1'b0;
      is_stack   = 1'b0;
      is_jump    = 1'b0;
      is_jsr     = 1'b0;
      is_return  = 1'b0;
      is_brk     = 1'b0;
      illegal    = 1'b0;

      case (opcode)
         // ****************************************************************
         // LDA — Load Accumulator
         // ****************************************************************
         8'hA9: begin addr_mode=`AM_IMM; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hA5: begin addr_mode=`AM_ZP;  alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hB5: begin addr_mode=`AM_ZPX; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hAD: begin addr_mode=`AM_ABS; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hBD: begin addr_mode=`AM_ABX; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hB9: begin addr_mode=`AM_ABY; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hA1: begin addr_mode=`AM_IZX; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hB1: begin addr_mode=`AM_IZY; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // LDX — Load X Register
         // ****************************************************************
         8'hA2: begin addr_mode=`AM_IMM; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_X; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hA6: begin addr_mode=`AM_ZP;  alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_X; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hB6: begin addr_mode=`AM_ZPY; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_X; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hAE: begin addr_mode=`AM_ABS; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_X; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hBE: begin addr_mode=`AM_ABY; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_X; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // LDY — Load Y Register
         // ****************************************************************
         8'hA0: begin addr_mode=`AM_IMM; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_Y; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hA4: begin addr_mode=`AM_ZP;  alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_Y; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hB4: begin addr_mode=`AM_ZPX; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_Y; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hAC: begin addr_mode=`AM_ABS; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_Y; mem_read=1; flag_mask=`FMASK_NZ; end
         8'hBC: begin addr_mode=`AM_ABX; alu_op=`ALU_PASS; reg_src=`REG_MEM; reg_dst=`REG_Y; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // STA — Store Accumulator
         // ****************************************************************
         8'h85: begin addr_mode=`AM_ZP;  reg_src=`REG_A; mem_write=1; end
         8'h95: begin addr_mode=`AM_ZPX; reg_src=`REG_A; mem_write=1; end
         8'h8D: begin addr_mode=`AM_ABS; reg_src=`REG_A; mem_write=1; end
         8'h9D: begin addr_mode=`AM_ABX; reg_src=`REG_A; mem_write=1; end
         8'h99: begin addr_mode=`AM_ABY; reg_src=`REG_A; mem_write=1; end
         8'h81: begin addr_mode=`AM_IZX; reg_src=`REG_A; mem_write=1; end
         8'h91: begin addr_mode=`AM_IZY; reg_src=`REG_A; mem_write=1; end

         // ****************************************************************
         // STX — Store X Register
         // ****************************************************************
         8'h86: begin addr_mode=`AM_ZP;  reg_src=`REG_X; mem_write=1; end
         8'h96: begin addr_mode=`AM_ZPY; reg_src=`REG_X; mem_write=1; end
         8'h8E: begin addr_mode=`AM_ABS; reg_src=`REG_X; mem_write=1; end

         // ****************************************************************
         // STY — Store Y Register
         // ****************************************************************
         8'h84: begin addr_mode=`AM_ZP;  reg_src=`REG_Y; mem_write=1; end
         8'h94: begin addr_mode=`AM_ZPX; reg_src=`REG_Y; mem_write=1; end
         8'h8C: begin addr_mode=`AM_ABS; reg_src=`REG_Y; mem_write=1; end

         // ****************************************************************
         // ADC — Add with Carry
         // ****************************************************************
         8'h69: begin addr_mode=`AM_IMM; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h65: begin addr_mode=`AM_ZP;  alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h75: begin addr_mode=`AM_ZPX; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h6D: begin addr_mode=`AM_ABS; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h7D: begin addr_mode=`AM_ABX; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h79: begin addr_mode=`AM_ABY; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h61: begin addr_mode=`AM_IZX; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'h71: begin addr_mode=`AM_IZY; alu_op=`ALU_ADC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end

         // ****************************************************************
         // SBC — Subtract with Carry
         // ****************************************************************
         8'hE9: begin addr_mode=`AM_IMM; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hE5: begin addr_mode=`AM_ZP;  alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hF5: begin addr_mode=`AM_ZPX; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hED: begin addr_mode=`AM_ABS; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hFD: begin addr_mode=`AM_ABX; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hF9: begin addr_mode=`AM_ABY; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hE1: begin addr_mode=`AM_IZX; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end
         8'hF1: begin addr_mode=`AM_IZY; alu_op=`ALU_SBC; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NVZC; end

         // ****************************************************************
         // AND — Logical AND
         // ****************************************************************
         8'h29: begin addr_mode=`AM_IMM; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h25: begin addr_mode=`AM_ZP;  alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h35: begin addr_mode=`AM_ZPX; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h2D: begin addr_mode=`AM_ABS; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h3D: begin addr_mode=`AM_ABX; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h39: begin addr_mode=`AM_ABY; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h21: begin addr_mode=`AM_IZX; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h31: begin addr_mode=`AM_IZY; alu_op=`ALU_AND; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // ORA — Logical OR
         // ****************************************************************
         8'h09: begin addr_mode=`AM_IMM; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h05: begin addr_mode=`AM_ZP;  alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h15: begin addr_mode=`AM_ZPX; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h0D: begin addr_mode=`AM_ABS; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h1D: begin addr_mode=`AM_ABX; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h19: begin addr_mode=`AM_ABY; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h01: begin addr_mode=`AM_IZX; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h11: begin addr_mode=`AM_IZY; alu_op=`ALU_ORA; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // EOR — Exclusive OR
         // ****************************************************************
         8'h49: begin addr_mode=`AM_IMM; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h45: begin addr_mode=`AM_ZP;  alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h55: begin addr_mode=`AM_ZPX; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h4D: begin addr_mode=`AM_ABS; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h5D: begin addr_mode=`AM_ABX; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h59: begin addr_mode=`AM_ABY; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h41: begin addr_mode=`AM_IZX; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end
         8'h51: begin addr_mode=`AM_IZY; alu_op=`ALU_EOR; reg_src=`REG_MEM; reg_dst=`REG_A; mem_read=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // CMP — Compare Accumulator
         // ****************************************************************
         8'hC9: begin addr_mode=`AM_IMM; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hC5: begin addr_mode=`AM_ZP;  alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hD5: begin addr_mode=`AM_ZPX; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hCD: begin addr_mode=`AM_ABS; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hDD: begin addr_mode=`AM_ABX; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hD9: begin addr_mode=`AM_ABY; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hC1: begin addr_mode=`AM_IZX; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hD1: begin addr_mode=`AM_IZY; alu_op=`ALU_CMP; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // CPX — Compare X Register
         // ****************************************************************
         8'hE0: begin addr_mode=`AM_IMM; alu_op=`ALU_CMP; alu_src_a=`REG_X; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hE4: begin addr_mode=`AM_ZP;  alu_op=`ALU_CMP; alu_src_a=`REG_X; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hEC: begin addr_mode=`AM_ABS; alu_op=`ALU_CMP; alu_src_a=`REG_X; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // CPY — Compare Y Register
         // ****************************************************************
         8'hC0: begin addr_mode=`AM_IMM; alu_op=`ALU_CMP; alu_src_a=`REG_Y; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hC4: begin addr_mode=`AM_ZP;  alu_op=`ALU_CMP; alu_src_a=`REG_Y; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end
         8'hCC: begin addr_mode=`AM_ABS; alu_op=`ALU_CMP; alu_src_a=`REG_Y; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // BIT — Bit Test
         // ****************************************************************
         8'h24: begin addr_mode=`AM_ZP;  alu_op=`ALU_BIT; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NVZ; end
         8'h2C: begin addr_mode=`AM_ABS; alu_op=`ALU_BIT; reg_src=`REG_MEM; mem_read=1; flag_mask=`FMASK_NVZ; end

         // ****************************************************************
         // ASL — Arithmetic Shift Left
         // ****************************************************************
         8'h0A: begin addr_mode=`AM_ACC; alu_op=`ALU_ASL; reg_src=`REG_A; reg_dst=`REG_A; flag_mask=`FMASK_NZC; end
         8'h06: begin addr_mode=`AM_ZP;  alu_op=`ALU_ASL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h16: begin addr_mode=`AM_ZPX; alu_op=`ALU_ASL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h0E: begin addr_mode=`AM_ABS; alu_op=`ALU_ASL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h1E: begin addr_mode=`AM_ABX; alu_op=`ALU_ASL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // LSR — Logical Shift Right
         // ****************************************************************
         8'h4A: begin addr_mode=`AM_ACC; alu_op=`ALU_LSR; reg_src=`REG_A; reg_dst=`REG_A; flag_mask=`FMASK_NZC; end
         8'h46: begin addr_mode=`AM_ZP;  alu_op=`ALU_LSR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h56: begin addr_mode=`AM_ZPX; alu_op=`ALU_LSR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h4E: begin addr_mode=`AM_ABS; alu_op=`ALU_LSR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h5E: begin addr_mode=`AM_ABX; alu_op=`ALU_LSR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // ROL — Rotate Left
         // ****************************************************************
         8'h2A: begin addr_mode=`AM_ACC; alu_op=`ALU_ROL; reg_src=`REG_A; reg_dst=`REG_A; flag_mask=`FMASK_NZC; end
         8'h26: begin addr_mode=`AM_ZP;  alu_op=`ALU_ROL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h36: begin addr_mode=`AM_ZPX; alu_op=`ALU_ROL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h2E: begin addr_mode=`AM_ABS; alu_op=`ALU_ROL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h3E: begin addr_mode=`AM_ABX; alu_op=`ALU_ROL; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // ROR — Rotate Right
         // ****************************************************************
         8'h6A: begin addr_mode=`AM_ACC; alu_op=`ALU_ROR; reg_src=`REG_A; reg_dst=`REG_A; flag_mask=`FMASK_NZC; end
         8'h66: begin addr_mode=`AM_ZP;  alu_op=`ALU_ROR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h76: begin addr_mode=`AM_ZPX; alu_op=`ALU_ROR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h6E: begin addr_mode=`AM_ABS; alu_op=`ALU_ROR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end
         8'h7E: begin addr_mode=`AM_ABX; alu_op=`ALU_ROR; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZC; end

         // ****************************************************************
         // INC — Increment Memory
         // ****************************************************************
         8'hE6: begin addr_mode=`AM_ZP;  alu_op=`ALU_INC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hF6: begin addr_mode=`AM_ZPX; alu_op=`ALU_INC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hEE: begin addr_mode=`AM_ABS; alu_op=`ALU_INC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hFE: begin addr_mode=`AM_ABX; alu_op=`ALU_INC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // DEC — Decrement Memory
         // ****************************************************************
         8'hC6: begin addr_mode=`AM_ZP;  alu_op=`ALU_DEC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hD6: begin addr_mode=`AM_ZPX; alu_op=`ALU_DEC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hCE: begin addr_mode=`AM_ABS; alu_op=`ALU_DEC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end
         8'hDE: begin addr_mode=`AM_ABX; alu_op=`ALU_DEC; reg_src=`REG_MEM; mem_read=1; mem_write=1; flag_mask=`FMASK_NZ; end

         // ****************************************************************
         // INX, INY, DEX, DEY — Register Increment/Decrement
         // ****************************************************************
         8'hE8: begin addr_mode=`AM_IMP; alu_op=`ALU_INC; alu_src_a=`REG_X; reg_src=`REG_X; reg_dst=`REG_X; flag_mask=`FMASK_NZ; end // INX
         8'hC8: begin addr_mode=`AM_IMP; alu_op=`ALU_INC; alu_src_a=`REG_Y; reg_src=`REG_Y; reg_dst=`REG_Y; flag_mask=`FMASK_NZ; end // INY
         8'hCA: begin addr_mode=`AM_IMP; alu_op=`ALU_DEC; alu_src_a=`REG_X; reg_src=`REG_X; reg_dst=`REG_X; flag_mask=`FMASK_NZ; end // DEX
         8'h88: begin addr_mode=`AM_IMP; alu_op=`ALU_DEC; alu_src_a=`REG_Y; reg_src=`REG_Y; reg_dst=`REG_Y; flag_mask=`FMASK_NZ; end // DEY

         // ****************************************************************
         // Transfer Instructions
         // ****************************************************************
         8'hAA: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_A;  reg_dst=`REG_X;  flag_mask=`FMASK_NZ; end // TAX
         8'hA8: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_A;  reg_dst=`REG_Y;  flag_mask=`FMASK_NZ; end // TAY
         8'h8A: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_X;  reg_dst=`REG_A;  flag_mask=`FMASK_NZ; end // TXA
         8'h98: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_Y;  reg_dst=`REG_A;  flag_mask=`FMASK_NZ; end // TYA
         8'hBA: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_SP; reg_dst=`REG_X;  flag_mask=`FMASK_NZ; end // TSX
         8'h9A: begin addr_mode=`AM_IMP; alu_op=`ALU_PASS; reg_src=`REG_X;  reg_dst=`REG_SP; end                      // TXS (no flags)

         // ****************************************************************
         // Flag Instructions
         // ****************************************************************
         8'h18: begin addr_mode=`AM_IMP; end // CLC
         8'h38: begin addr_mode=`AM_IMP; end // SEC
         8'h58: begin addr_mode=`AM_IMP; end // CLI
         8'h78: begin addr_mode=`AM_IMP; end // SEI
         8'hB8: begin addr_mode=`AM_IMP; end // CLV
         8'hD8: begin addr_mode=`AM_IMP; end // CLD
         8'hF8: begin addr_mode=`AM_IMP; end // SED

         // ****************************************************************
         // Branch Instructions
         // ****************************************************************
         8'h10: begin addr_mode=`AM_REL; is_branch=1; end // BPL
         8'h30: begin addr_mode=`AM_REL; is_branch=1; end // BMI
         8'h50: begin addr_mode=`AM_REL; is_branch=1; end // BVC
         8'h70: begin addr_mode=`AM_REL; is_branch=1; end // BVS
         8'h90: begin addr_mode=`AM_REL; is_branch=1; end // BCC
         8'hB0: begin addr_mode=`AM_REL; is_branch=1; end // BCS
         8'hD0: begin addr_mode=`AM_REL; is_branch=1; end // BNE
         8'hF0: begin addr_mode=`AM_REL; is_branch=1; end // BEQ

         // ****************************************************************
         // Jump Instructions
         // ****************************************************************
         8'h4C: begin addr_mode=`AM_ABS; is_jump=1; end // JMP absolute
         8'h6C: begin addr_mode=`AM_IND; is_jump=1; end // JMP indirect
         8'h20: begin addr_mode=`AM_ABS; is_jsr=1;  end // JSR

         // ****************************************************************
         // Return Instructions
         // ****************************************************************
         8'h60: begin addr_mode=`AM_IMP; is_return=1; end // RTS
         8'h40: begin addr_mode=`AM_IMP; is_return=1; end // RTI

         // ****************************************************************
         // Stack Instructions
         // ****************************************************************
         8'h48: begin addr_mode=`AM_IMP; is_stack=1; reg_src=`REG_A; end // PHA
         8'h08: begin addr_mode=`AM_IMP; is_stack=1; reg_src=`REG_P; end // PHP
         8'h68: begin addr_mode=`AM_IMP; is_stack=1; reg_src=`REG_MEM; alu_op=`ALU_PASS; reg_dst=`REG_A; flag_mask=`FMASK_NZ; end // PLA
         8'h28: begin addr_mode=`AM_IMP; is_stack=1; reg_src=`REG_MEM; alu_op=`ALU_PASS; reg_dst=`REG_P; end // PLP

         // ****************************************************************
         // BRK — Software Interrupt
         // ****************************************************************
         8'h00: begin addr_mode=`AM_IMP; is_brk=1; end

         // ****************************************************************
         // NOP
         // ****************************************************************
         8'hEA: begin addr_mode=`AM_IMP; end

         // All other opcodes are illegal
         default: begin
            illegal = 1'b1;
         end
      endcase
   end

endmodule
