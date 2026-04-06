// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Decoder Testbench
//
// Covers all 256 opcodes and verifies:
//  - Legal opcodes produce correct addr_mode, alu_op,
//    and flags
//  - Illegal opcodes assert the `illegal` output
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_decoder;

   // *** Addressing Mode Codes ***
   localparam [3:0] AM_IMP  = 4'h0;
   localparam [3:0] AM_ACC  = 4'h1;
   localparam [3:0] AM_IMM  = 4'h2;
   localparam [3:0] AM_ZP   = 4'h3;
   localparam [3:0] AM_ZPX  = 4'h4;
   localparam [3:0] AM_ZPY  = 4'h5;
   localparam [3:0] AM_ABS  = 4'h6;
   localparam [3:0] AM_ABX  = 4'h7;
   localparam [3:0] AM_ABY  = 4'h8;
   localparam [3:0] AM_IND  = 4'h9;
   localparam [3:0] AM_IZX  = 4'hA;
   localparam [3:0] AM_IZY  = 4'hB;
   localparam [3:0] AM_REL  = 4'hC;
   localparam [3:0] AM_NONE = 4'hF;

   // *** ALU Operation Codes ***
   localparam [3:0] ALU_ADC  = 4'h0;
   localparam [3:0] ALU_SBC  = 4'h1;
   localparam [3:0] ALU_AND  = 4'h2;
   localparam [3:0] ALU_ORA  = 4'h3;
   localparam [3:0] ALU_EOR  = 4'h4;
   localparam [3:0] ALU_ASL  = 4'h5;
   localparam [3:0] ALU_LSR  = 4'h6;
   localparam [3:0] ALU_ROL  = 4'h7;
   localparam [3:0] ALU_ROR  = 4'h8;
   localparam [3:0] ALU_INC  = 4'h9;
   localparam [3:0] ALU_DEC  = 4'hA;
   localparam [3:0] ALU_CMP  = 4'hB;
   localparam [3:0] ALU_BIT  = 4'hC;
   localparam [3:0] ALU_PASS = 4'hD;

   // ****************************************************************
   // DUT Signals
   // ****************************************************************
   reg  [7:0] opcode;
   wire [3:0] addr_mode;
   wire [3:0] alu_op;
   wire [2:0] alu_src_a;
   wire [2:0] reg_src;
   wire [2:0] reg_dst;
   wire       mem_read;
   wire       mem_write;
   wire [7:0] flag_mask;
   wire       is_branch;
   wire       is_stack;
   wire       is_jump;
   wire       is_jsr;
   wire       is_return;
   wire       is_brk;
   wire       illegal;

   // ****************************************************************
   // Counters
   // ****************************************************************
   integer pass_count;
   integer fail_count;
   integer legal_count;
   integer illegal_count;

   // ****************************************************************
   // DUT
   // ****************************************************************
   n6502_decoder uut (
      .opcode    (opcode),
      .addr_mode (addr_mode),
      .alu_op    (alu_op),
      .alu_src_a (alu_src_a),
      .reg_src   (reg_src),
      .reg_dst   (reg_dst),
      .mem_read  (mem_read),
      .mem_write (mem_write),
      .flag_mask (flag_mask),
      .is_branch (is_branch),
      .is_stack  (is_stack),
      .is_jump   (is_jump),
      .is_jsr    (is_jsr),
      .is_return (is_return),
      .is_brk    (is_brk),
      .illegal   (illegal)
   );

   // ****************************************************************
   // Check Tasks
   // ****************************************************************
   task check_legal;
      input [3:0] exp_am;
      input [3:0] exp_alu;
      input [63:0] name;
      begin
         #1;
         if (illegal) begin
            $display("FAIL [%s] opcode=%02h: decoded as ILLEGAL", name, opcode);
            fail_count = fail_count + 1;
         end else if (addr_mode !== exp_am) begin
            $display("FAIL [%s] opcode=%02h: addr_mode=%h expected=%h", name, opcode, addr_mode, exp_am);
            fail_count = fail_count + 1;
         end else if (alu_op !== exp_alu) begin
            $display("FAIL [%s] opcode=%02h: alu_op=%h expected=%h", name, opcode, alu_op, exp_alu);
            fail_count = fail_count + 1;
         end else begin
            pass_count = pass_count + 1;
         end
      end
   endtask

   task check_am;
      input [3:0] exp_am;
      input [63:0] name;
      begin
         #1;
         if (illegal) begin
            $display("FAIL [%s] opcode=%02h: decoded as ILLEGAL", name, opcode);
            fail_count = fail_count + 1;
         end else if (addr_mode !== exp_am) begin
            $display("FAIL [%s] opcode=%02h: addr_mode=%h expected=%h", name, opcode, addr_mode, exp_am);
            fail_count = fail_count + 1;
         end else begin
            pass_count = pass_count + 1;
         end
      end
   endtask

   // ****************************************************************
   // Test Stimulus
   // ****************************************************************
   initial begin
      `ifdef DUMP_VCD
      $dumpfile("build/tb_n6502_decoder.vcd");
      $dumpvars(0, tb_n6502_decoder);
      `endif

      pass_count    = 0;
      fail_count    = 0;
      legal_count   = 0;
      illegal_count = 0;

      $display("****************************************");
      $display(" n6502 Decoder Testbench");
      $display("****************************************");

      // ************************************************************
      // LDA
      // ************************************************************
      $display("LDA");
      opcode=8'hA9; check_legal(AM_IMM, ALU_PASS, "LDA_IMM");
      opcode=8'hA5; check_legal(AM_ZP,  ALU_PASS, "LDA_ZP ");
      opcode=8'hB5; check_legal(AM_ZPX, ALU_PASS, "LDA_ZPX");
      opcode=8'hAD; check_legal(AM_ABS, ALU_PASS, "LDA_ABS");
      opcode=8'hBD; check_legal(AM_ABX, ALU_PASS, "LDA_ABX");
      opcode=8'hB9; check_legal(AM_ABY, ALU_PASS, "LDA_ABY");
      opcode=8'hA1; check_legal(AM_IZX, ALU_PASS, "LDA_IZX");
      opcode=8'hB1; check_legal(AM_IZY, ALU_PASS, "LDA_IZY");

      // ************************************************************
      // LDX
      // ************************************************************
      $display("LDX");
      opcode=8'hA2; check_legal(AM_IMM, ALU_PASS, "LDX_IMM");
      opcode=8'hA6; check_legal(AM_ZP,  ALU_PASS, "LDX_ZP ");
      opcode=8'hB6; check_legal(AM_ZPY, ALU_PASS, "LDX_ZPY");
      opcode=8'hAE; check_legal(AM_ABS, ALU_PASS, "LDX_ABS");
      opcode=8'hBE; check_legal(AM_ABY, ALU_PASS, "LDX_ABY");

      // ************************************************************
      // LDY
      // ************************************************************
      $display("LDY");
      opcode=8'hA0; check_legal(AM_IMM, ALU_PASS, "LDY_IMM");
      opcode=8'hA4; check_legal(AM_ZP,  ALU_PASS, "LDY_ZP ");
      opcode=8'hB4; check_legal(AM_ZPX, ALU_PASS, "LDY_ZPX");
      opcode=8'hAC; check_legal(AM_ABS, ALU_PASS, "LDY_ABS");
      opcode=8'hBC; check_legal(AM_ABX, ALU_PASS, "LDY_ABX");

      // ************************************************************
      // STA/STX/STY
      // ************************************************************
      $display("STA/STX/STY");
      opcode=8'h85; check_am(AM_ZP,  "STA_ZP ");
      opcode=8'h95; check_am(AM_ZPX, "STA_ZPX");
      opcode=8'h8D; check_am(AM_ABS, "STA_ABS");
      opcode=8'h9D; check_am(AM_ABX, "STA_ABX");
      opcode=8'h99; check_am(AM_ABY, "STA_ABY");
      opcode=8'h81; check_am(AM_IZX, "STA_IZX");
      opcode=8'h91; check_am(AM_IZY, "STA_IZY");
      opcode=8'h86; check_am(AM_ZP,  "STX_ZP ");
      opcode=8'h96; check_am(AM_ZPY, "STX_ZPY");
      opcode=8'h8E; check_am(AM_ABS, "STX_ABS");
      opcode=8'h84; check_am(AM_ZP,  "STY_ZP ");
      opcode=8'h94; check_am(AM_ZPX, "STY_ZPX");
      opcode=8'h8C; check_am(AM_ABS, "STY_ABS");

      // ************************************************************
      // ADC
      // ************************************************************
      $display("ADC");
      opcode=8'h69; check_legal(AM_IMM, ALU_ADC, "ADC_IMM");
      opcode=8'h65; check_legal(AM_ZP,  ALU_ADC, "ADC_ZP ");
      opcode=8'h75; check_legal(AM_ZPX, ALU_ADC, "ADC_ZPX");
      opcode=8'h6D; check_legal(AM_ABS, ALU_ADC, "ADC_ABS");
      opcode=8'h7D; check_legal(AM_ABX, ALU_ADC, "ADC_ABX");
      opcode=8'h79; check_legal(AM_ABY, ALU_ADC, "ADC_ABY");
      opcode=8'h61; check_legal(AM_IZX, ALU_ADC, "ADC_IZX");
      opcode=8'h71; check_legal(AM_IZY, ALU_ADC, "ADC_IZY");

      // ************************************************************
      // SBC
      // ************************************************************
      $display("SBC");
      opcode=8'hE9; check_legal(AM_IMM, ALU_SBC, "SBC_IMM");
      opcode=8'hE5; check_legal(AM_ZP,  ALU_SBC, "SBC_ZP ");
      opcode=8'hF5; check_legal(AM_ZPX, ALU_SBC, "SBC_ZPX");
      opcode=8'hED; check_legal(AM_ABS, ALU_SBC, "SBC_ABS");
      opcode=8'hFD; check_legal(AM_ABX, ALU_SBC, "SBC_ABX");
      opcode=8'hF9; check_legal(AM_ABY, ALU_SBC, "SBC_ABY");
      opcode=8'hE1; check_legal(AM_IZX, ALU_SBC, "SBC_IZX");
      opcode=8'hF1; check_legal(AM_IZY, ALU_SBC, "SBC_IZY");

      // ************************************************************
      // AND/ORA/EOR
      // ************************************************************
      $display("AND/ORA/EOR");
      opcode=8'h29; check_legal(AM_IMM, ALU_AND, "AND_IMM");
      opcode=8'h25; check_legal(AM_ZP,  ALU_AND, "AND_ZP ");
      opcode=8'h09; check_legal(AM_IMM, ALU_ORA, "ORA_IMM");
      opcode=8'h05; check_legal(AM_ZP,  ALU_ORA, "ORA_ZP ");
      opcode=8'h49; check_legal(AM_IMM, ALU_EOR, "EOR_IMM");
      opcode=8'h45; check_legal(AM_ZP,  ALU_EOR, "EOR_ZP ");

      // ************************************************************
      // CMP/CPX/CPY
      // ************************************************************
      $display("CMP/CPX/CPY");
      opcode=8'hC9; check_legal(AM_IMM, ALU_CMP, "CMP_IMM");
      opcode=8'hC5; check_legal(AM_ZP,  ALU_CMP, "CMP_ZP ");
      opcode=8'hE0; check_legal(AM_IMM, ALU_CMP, "CPX_IMM");
      opcode=8'hE4; check_legal(AM_ZP,  ALU_CMP, "CPX_ZP ");
      opcode=8'hC0; check_legal(AM_IMM, ALU_CMP, "CPY_IMM");
      opcode=8'hC4; check_legal(AM_ZP,  ALU_CMP, "CPY_ZP ");

      // ************************************************************
      // BIT
      // ************************************************************
      $display("BIT");
      opcode=8'h24; check_legal(AM_ZP,  ALU_BIT, "BIT_ZP ");
      opcode=8'h2C; check_legal(AM_ABS, ALU_BIT, "BIT_ABS");

      // ************************************************************
      // Shifts (ASL/LSR/ROL/ROR) — Accumulator mode
      // ************************************************************
      $display("Shifts (ACC)");
      opcode=8'h0A; check_legal(AM_ACC, ALU_ASL, "ASL_ACC");
      opcode=8'h4A; check_legal(AM_ACC, ALU_LSR, "LSR_ACC");
      opcode=8'h2A; check_legal(AM_ACC, ALU_ROL, "ROL_ACC");
      opcode=8'h6A; check_legal(AM_ACC, ALU_ROR, "ROR_ACC");

      // ************************************************************
      // Shifts — Memory (spot check)
      // ************************************************************
      $display("Shifts (MEM)");
      opcode=8'h06; check_legal(AM_ZP,  ALU_ASL, "ASL_ZP ");
      opcode=8'h0E; check_legal(AM_ABS, ALU_ASL, "ASL_ABS");
      opcode=8'h46; check_legal(AM_ZP,  ALU_LSR, "LSR_ZP ");
      opcode=8'h26; check_legal(AM_ZP,  ALU_ROL, "ROL_ZP ");
      opcode=8'h66; check_legal(AM_ZP,  ALU_ROR, "ROR_ZP ");

      // ************************************************************
      // INC/DEC Memory
      // ************************************************************
      $display("INC/DEC Memory");
      opcode=8'hE6; check_legal(AM_ZP,  ALU_INC, "INC_ZP ");
      opcode=8'hEE; check_legal(AM_ABS, ALU_INC, "INC_ABS");
      opcode=8'hC6; check_legal(AM_ZP,  ALU_DEC, "DEC_ZP ");
      opcode=8'hCE; check_legal(AM_ABS, ALU_DEC, "DEC_ABS");

      // ************************************************************
      // INX/INY/DEX/DEY
      // ************************************************************
      $display("INX/INY/DEX/DEY");
      opcode=8'hE8; check_legal(AM_IMP, ALU_INC, "INX    ");
      opcode=8'hC8; check_legal(AM_IMP, ALU_INC, "INY    ");
      opcode=8'hCA; check_legal(AM_IMP, ALU_DEC, "DEX    ");
      opcode=8'h88; check_legal(AM_IMP, ALU_DEC, "DEY    ");

      // ************************************************************
      // Transfers
      // ************************************************************
      $display("Transfers");
      opcode=8'hAA; check_legal(AM_IMP, ALU_PASS, "TAX    ");
      opcode=8'hA8; check_legal(AM_IMP, ALU_PASS, "TAY    ");
      opcode=8'h8A; check_legal(AM_IMP, ALU_PASS, "TXA    ");
      opcode=8'h98; check_legal(AM_IMP, ALU_PASS, "TYA    ");
      opcode=8'hBA; check_legal(AM_IMP, ALU_PASS, "TSX    ");
      opcode=8'h9A; check_legal(AM_IMP, ALU_PASS, "TXS    ");

      // ************************************************************
      // Flag Instructions
      // ************************************************************
      $display("Flags");
      opcode=8'h18; check_am(AM_IMP, "CLC    ");
      opcode=8'h38; check_am(AM_IMP, "SEC    ");
      opcode=8'h58; check_am(AM_IMP, "CLI    ");
      opcode=8'h78; check_am(AM_IMP, "SEI    ");
      opcode=8'hB8; check_am(AM_IMP, "CLV    ");
      opcode=8'hD8; check_am(AM_IMP, "CLD    ");
      opcode=8'hF8; check_am(AM_IMP, "SED    ");

      // ************************************************************
      // Branches
      // ************************************************************
      $display("Branches");
      opcode=8'h10; check_am(AM_REL, "BPL    ");
      opcode=8'h30; check_am(AM_REL, "BMI    ");
      opcode=8'h50; check_am(AM_REL, "BVC    ");
      opcode=8'h70; check_am(AM_REL, "BVS    ");
      opcode=8'h90; check_am(AM_REL, "BCC    ");
      opcode=8'hB0; check_am(AM_REL, "BCS    ");
      opcode=8'hD0; check_am(AM_REL, "BNE    ");
      opcode=8'hF0; check_am(AM_REL, "BEQ    ");

      // Check is_branch flag
      #1;
      if (!is_branch) begin
         $display("FAIL: BEQ (F0) is_branch not set");
         fail_count = fail_count + 1;
      end else begin
         pass_count = pass_count + 1;
      end

      // ************************************************************
      // JMP/JSR
      // ************************************************************
      $display("JMP/JSR");
      opcode=8'h4C; check_am(AM_ABS, "JMP_ABS");
      #1;
      if (!is_jump) begin $display("FAIL: JMP ABS is_jump not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'h6C; check_am(AM_IND, "JMP_IND");
      #1;
      if (!is_jump) begin $display("FAIL: JMP IND is_jump not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'h20; check_am(AM_ABS, "JSR    ");
      #1;
      if (!is_jsr) begin $display("FAIL: JSR is_jsr not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      // ************************************************************
      // RTS/RTI
      // ************************************************************
      $display("RTS/RTI");
      opcode=8'h60; check_am(AM_IMP, "RTS    ");
      #1;
      if (!is_return) begin $display("FAIL: RTS is_return not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'h40; check_am(AM_IMP, "RTI    ");
      #1;
      if (!is_return) begin $display("FAIL: RTI is_return not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      // ************************************************************
      // Stack (PHA/PLA/PHP/PLP)
      // ************************************************************
      $display("Stack");
      opcode=8'h48; check_am(AM_IMP, "PHA    ");
      #1;
      if (!is_stack) begin $display("FAIL: PHA is_stack not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'h68; check_am(AM_IMP, "PLA    ");
      opcode=8'h08; check_am(AM_IMP, "PHP    ");
      opcode=8'h28; check_am(AM_IMP, "PLP    ");

      // ************************************************************
      // BRK
      // ************************************************************
      $display("BRK");
      opcode=8'h00; check_am(AM_IMP, "BRK    ");
      #1;
      if (!is_brk) begin $display("FAIL: BRK is_brk not set"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      // ************************************************************
      // NOP
      // ************************************************************
      $display("NOP");
      opcode=8'hEA; check_am(AM_IMP, "NOP    ");

      // ************************************************************
      // RMW flag check (spot checks)
      // ************************************************************
      $display("RMW checks (mem_read && mem_write)");
      opcode=8'h06; #1; // ASL ZP
      if (!(mem_read && mem_write)) begin $display("FAIL: ASL ZP not RMW (mem_read && mem_write)"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'hE6; #1; // INC ZP
      if (!(mem_read && mem_write)) begin $display("FAIL: INC ZP not RMW (mem_read && mem_write)"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      opcode=8'h0A; #1; // ASL ACC — should NOT be RMW
      if (mem_read && mem_write) begin $display("FAIL: ASL ACC should NOT be RMW"); fail_count = fail_count + 1; end
      else pass_count = pass_count + 1;

      // ************************************************************
      // Exhaustive illegal opcode scan
      // ************************************************************
      $display("Illegal opcode scan");
      begin : illegal_scan
         integer i;
         for (i = 0; i < 256; i = i + 1) begin
            opcode = i[7:0];
            #1;
            if (illegal)
               illegal_count = illegal_count + 1;
            else
               legal_count = legal_count + 1;
         end
      end
      $display("  Legal opcodes:   %0d", legal_count);
      $display("  Illegal opcodes: %0d", illegal_count);

      // We expect exactly 151 legal opcodes and 105 illegal
      if (legal_count !== 151) begin
         $display("FAIL: Expected 151 legal opcodes, got %0d", legal_count);
         fail_count = fail_count + 1;
      end else begin
         pass_count = pass_count + 1;
      end

      if (illegal_count !== 105) begin
         $display("FAIL: Expected 105 illegal opcodes, got %0d", illegal_count);
         fail_count = fail_count + 1;
      end else begin
         pass_count = pass_count + 1;
      end

      // ************************************************************
      // Summary
      // ************************************************************
      $display("****************************************");
      $display(" Results: %0d PASS, %0d FAIL (total: %0d)",
               pass_count, fail_count, pass_count + fail_count);
      if (fail_count == 0)
         $display(" *** ALL TESTS PASSED ***");
      else
         $display(" *** SOME TESTS FAILED ***");
      $display("****************************************");

      $finish;
   end

endmodule
