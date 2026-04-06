// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// ALU Testbench
//
// Covers all 14 ALU operations with boundary values,
// carry chain, overflow detection and flag correctness.
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_alu;

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
   reg        clk;
   reg  [3:0] alu_op;
   reg  [7:0] alu_a;
   reg  [7:0] alu_b;
   reg        carry_in;
   wire [7:0] alu_out;
   wire       carry_out;
   wire       overflow_out;
   wire       zero_out;
   wire       negative_out;

   // ****************************************************************
   // Counters
   // ****************************************************************
   integer pass_count;
   integer fail_count;
   integer test_num;

   // ****************************************************************
   // Clock (100 MHz)
   // ****************************************************************
   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   // ****************************************************************
   // DUT
   // ****************************************************************
   n6502_alu uut (
      .alu_op       (alu_op),
      .alu_a        (alu_a),
      .alu_b        (alu_b),
      .carry_in     (carry_in),
      .alu_out      (alu_out),
      .carry_out    (carry_out),
      .overflow_out (overflow_out),
      .zero_out     (zero_out),
      .negative_out (negative_out)
   );

   // ****************************************************************
   // Check Task
   // ****************************************************************
   task check;
      input [7:0]  exp_out;
      input        exp_c;
      input        exp_v;
      input        exp_z;
      input        exp_n;
      input [63:0] test_name; // 8 chars max for display
      begin
         test_num = test_num + 1;
         #1; // wait for combinational propagation
         if (alu_out !== exp_out || carry_out !== exp_c ||
            overflow_out !== exp_v || zero_out !== exp_z ||
            negative_out !== exp_n) begin
            $display("FAIL #%0d [%s] op=%h a=%h b=%h ci=%b | out=%h c=%b v=%b z=%b n=%b | exp out=%h c=%b v=%b z=%b n=%b",
               test_num, test_name, alu_op, alu_a, alu_b, carry_in,
               alu_out, carry_out, overflow_out, zero_out, negative_out,
               exp_out, exp_c, exp_v, exp_z, exp_n);
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
      $dumpfile("build/tb_n6502_alu.vcd");
      $dumpvars(0, tb_n6502_alu);
      `endif

      pass_count = 0;
      fail_count = 0;
      test_num   = 0;

      $display("****************************************");
      $display(" n6502 ALU Testbench");
      $display("****************************************");

      // ************************************************************
      // ADC Tests
      // ************************************************************
      $display("ADC Tests");

      // Basic addition: 0 + 0 + 0 = 0
      alu_op = ALU_ADC; alu_a = 8'h00; alu_b = 8'h00; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "ADC_00 ");

      // Basic addition: 1 + 2 + 0 = 3
      alu_op = ALU_ADC; alu_a = 8'h01; alu_b = 8'h02; carry_in = 0;
      check(8'h03, 1'b0, 1'b0, 1'b0, 1'b0, "ADC_12 ");

      // Addition with carry in: 1 + 2 + 1 = 4
      alu_op = ALU_ADC; alu_a = 8'h01; alu_b = 8'h02; carry_in = 1;
      check(8'h04, 1'b0, 1'b0, 1'b0, 1'b0, "ADC_C  ");

      // Carry out: FF + 01 + 0 = 00 with carry
      alu_op = ALU_ADC; alu_a = 8'hFF; alu_b = 8'h01; carry_in = 0;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "ADC_CO ");

      // Carry out: FF + FF + 0 = FE with carry
      alu_op = ALU_ADC; alu_a = 8'hFF; alu_b = 8'hFF; carry_in = 0;
      check(8'hFE, 1'b1, 1'b0, 1'b0, 1'b1, "ADC_FE ");

      // Carry out: FF + FF + 1 = FF with carry
      alu_op = ALU_ADC; alu_a = 8'hFF; alu_b = 8'hFF; carry_in = 1;
      check(8'hFF, 1'b1, 1'b0, 1'b0, 1'b1, "ADC_FF ");

      // Positive overflow: 7F + 01 = 80 (127 + 1 = -128, overflow!)
      alu_op = ALU_ADC; alu_a = 8'h7F; alu_b = 8'h01; carry_in = 0;
      check(8'h80, 1'b0, 1'b1, 1'b0, 1'b1, "ADC_OV+");

      // Negative overflow: 80 + FF = 7F (-128 + -1 = 127, overflow!)
      alu_op = ALU_ADC; alu_a = 8'h80; alu_b = 8'hFF; carry_in = 0;
      check(8'h7F, 1'b1, 1'b1, 1'b0, 1'b0, "ADC_OV-");

      // No overflow: 7F + 80 = FF (positive + negative, never overflows)
      alu_op = ALU_ADC; alu_a = 8'h7F; alu_b = 8'h80; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "ADC_NOV");

      // ************************************************************
      // SBC Tests
      // ************************************************************
      $display("SBC Tests");

      // Basic subtraction: 5 - 3 - 0 = 2 (with carry=1, no borrow)
      alu_op = ALU_SBC; alu_a = 8'h05; alu_b = 8'h03; carry_in = 1;
      check(8'h02, 1'b1, 1'b0, 1'b0, 1'b0, "SBC_53 ");

      // Subtraction with borrow: 5 - 3 - 1 = 1 (carry=0 means borrow)
      alu_op = ALU_SBC; alu_a = 8'h05; alu_b = 8'h03; carry_in = 0;
      check(8'h01, 1'b1, 1'b0, 1'b0, 1'b0, "SBC_BRW");

      // Result zero: 42 - 42 = 0
      alu_op = ALU_SBC; alu_a = 8'h42; alu_b = 8'h42; carry_in = 1;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "SBC_ZR ");

      // Borrow (underflow): 00 - 01 = FF with borrow
      alu_op = ALU_SBC; alu_a = 8'h00; alu_b = 8'h01; carry_in = 1;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "SBC_UF ");

      // Signed overflow: 80 - 01 = 7F (-128 - 1 = 127, overflow!)
      alu_op = ALU_SBC; alu_a = 8'h80; alu_b = 8'h01; carry_in = 1;
      check(8'h7F, 1'b1, 1'b1, 1'b0, 1'b0, "SBC_OV ");

      // Signed overflow: 7F - FF = 80 (127 - (-1) = -128, overflow!)
      alu_op = ALU_SBC; alu_a = 8'h7F; alu_b = 8'hFF; carry_in = 1;
      check(8'h80, 1'b0, 1'b1, 1'b0, 1'b1, "SBC_OV2");

      // ************************************************************
      // Logic Tests
      // ************************************************************
      $display("Logic Tests");

      // AND
      alu_op = ALU_AND; alu_a = 8'hF0; alu_b = 8'h3C; carry_in = 0;
      check(8'h30, 1'b0, 1'b0, 1'b0, 1'b0, "AND_1  ");

      alu_op = ALU_AND; alu_a = 8'hFF; alu_b = 8'h00; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "AND_Z  ");

      alu_op = ALU_AND; alu_a = 8'hFF; alu_b = 8'hFF; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "AND_FF ");

      // ORA
      alu_op = ALU_ORA; alu_a = 8'hF0; alu_b = 8'h0F; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "ORA_FF ");

      alu_op = ALU_ORA; alu_a = 8'h00; alu_b = 8'h00; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "ORA_Z  ");

      // EOR
      alu_op = ALU_EOR; alu_a = 8'hFF; alu_b = 8'hFF; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "EOR_Z  ");

      alu_op = ALU_EOR; alu_a = 8'hAA; alu_b = 8'h55; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "EOR_FF ");

      // ************************************************************
      // Shift/Rotate Tests
      // ************************************************************
      $display("Shift/Rotate Tests");

      // ASL: 0x55 << 1 = 0xAA, C=0
      alu_op = ALU_ASL; alu_a = 8'h00; alu_b = 8'h55; carry_in = 0;
      check(8'hAA, 1'b0, 1'b0, 1'b0, 1'b1, "ASL_55 ");

      // ASL: 0x80 << 1 = 0x00, C=1
      alu_op = ALU_ASL; alu_a = 8'h00; alu_b = 8'h80; carry_in = 0;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "ASL_80 ");

      // LSR: 0xAA >> 1 = 0x55, C=0
      alu_op = ALU_LSR; alu_a = 8'h00; alu_b = 8'hAA; carry_in = 0;
      check(8'h55, 1'b0, 1'b0, 1'b0, 1'b0, "LSR_AA ");

      // LSR: 0x01 >> 1 = 0x00, C=1
      alu_op = ALU_LSR; alu_a = 8'h00; alu_b = 8'h01; carry_in = 0;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "LSR_01 ");

      // ROL: 0x55, C=1 -> 0xAB, C=0
      alu_op = ALU_ROL; alu_a = 8'h00; alu_b = 8'h55; carry_in = 1;
      check(8'hAB, 1'b0, 1'b0, 1'b0, 1'b1, "ROL_55 ");

      // ROL: 0x80, C=0 -> 0x00, C=1
      alu_op = ALU_ROL; alu_a = 8'h00; alu_b = 8'h80; carry_in = 0;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "ROL_80 ");

      // ROR: 0xAA, C=0 -> 0x55, C=0
      alu_op = ALU_ROR; alu_a = 8'h00; alu_b = 8'hAA; carry_in = 0;
      check(8'h55, 1'b0, 1'b0, 1'b0, 1'b0, "ROR_AA ");

      // ROR: 0x01, C=1 -> 0x80, C=1
      alu_op = ALU_ROR; alu_a = 8'h00; alu_b = 8'h01; carry_in = 1;
      check(8'h80, 1'b1, 1'b0, 1'b0, 1'b1, "ROR_01 ");

      // ************************************************************
      // INC/DEC Tests
      // ************************************************************
      $display("INC/DEC Tests");

      // INC: 0x00 + 1 = 0x01
      alu_op = ALU_INC; alu_a = 8'h00; alu_b = 8'h00; carry_in = 0;
      check(8'h01, 1'b0, 1'b0, 1'b0, 1'b0, "INC_00 ");

      // INC: 0xFF + 1 = 0x00 (wraps)
      alu_op = ALU_INC; alu_a = 8'h00; alu_b = 8'hFF; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "INC_FF ");

      // INC: 0x7F + 1 = 0x80
      alu_op = ALU_INC; alu_a = 8'h00; alu_b = 8'h7F; carry_in = 0;
      check(8'h80, 1'b0, 1'b0, 1'b0, 1'b1, "INC_7F ");

      // DEC: 0x01 - 1 = 0x00
      alu_op = ALU_DEC; alu_a = 8'h00; alu_b = 8'h01; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "DEC_01 ");

      // DEC: 0x00 - 1 = 0xFF (wraps)
      alu_op = ALU_DEC; alu_a = 8'h00; alu_b = 8'h00; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "DEC_00 ");

      // DEC: 0x80 - 1 = 0x7F
      alu_op = ALU_DEC; alu_a = 8'h00; alu_b = 8'h80; carry_in = 0;
      check(8'h7F, 1'b0, 1'b0, 1'b0, 1'b0, "DEC_80 ");

      // ************************************************************
      // CMP Tests
      // ************************************************************
      $display("CMP Tests");

      // CMP: A == B -> Z=1, C=1
      alu_op = ALU_CMP; alu_a = 8'h42; alu_b = 8'h42; carry_in = 0;
      check(8'h00, 1'b1, 1'b0, 1'b1, 1'b0, "CMP_EQ ");

      // CMP: A > B -> C=1, Z=0
      alu_op = ALU_CMP; alu_a = 8'h50; alu_b = 8'h30; carry_in = 0;
      check(8'h20, 1'b1, 1'b0, 1'b0, 1'b0, "CMP_GT ");

      // CMP: A < B -> C=0, N=1
      alu_op = ALU_CMP; alu_a = 8'h30; alu_b = 8'h50; carry_in = 0;
      check(8'hE0, 1'b0, 1'b0, 1'b0, 1'b1, "CMP_LT ");

      // CMP: 0x00 vs 0x01 -> C=0
      alu_op = ALU_CMP; alu_a = 8'h00; alu_b = 8'h01; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "CMP_01 ");

      // ************************************************************
      // BIT Tests
      // ************************************************************
      $display("BIT Tests");

      // BIT: A=FF, M=80 -> Z=0, N=1 (from M[7]), V=0 (from M[6])
      alu_op = ALU_BIT; alu_a = 8'hFF; alu_b = 8'h80; carry_in = 0;
      check(8'h80, 1'b0, 1'b0, 1'b0, 1'b1, "BIT_80 ");

      // BIT: A=FF, M=40 -> Z=0, N=0, V=1 (from M[6])
      alu_op = ALU_BIT; alu_a = 8'hFF; alu_b = 8'h40; carry_in = 0;
      check(8'h40, 1'b0, 1'b1, 1'b0, 1'b0, "BIT_40 ");

      // BIT: A=FF, M=C0 -> Z=0, N=1, V=1
      alu_op = ALU_BIT; alu_a = 8'hFF; alu_b = 8'hC0; carry_in = 0;
      check(8'hC0, 1'b0, 1'b1, 1'b0, 1'b1, "BIT_C0 ");

      // BIT: A=0F, M=F0 -> Z=1 (AND result is 0)
      alu_op = ALU_BIT; alu_a = 8'h0F; alu_b = 8'hF0; carry_in = 0;
      check(8'h00, 1'b0, 1'b1, 1'b1, 1'b1, "BIT_Z  ");

      // ************************************************************
      // PASS Tests
      // ************************************************************
      $display("PASS Tests");

      alu_op = ALU_PASS; alu_a = 8'h00; alu_b = 8'h42; carry_in = 0;
      check(8'h42, 1'b0, 1'b0, 1'b0, 1'b0, "PASS_42");

      alu_op = ALU_PASS; alu_a = 8'h00; alu_b = 8'h00; carry_in = 0;
      check(8'h00, 1'b0, 1'b0, 1'b1, 1'b0, "PASS_00");

      alu_op = ALU_PASS; alu_a = 8'h00; alu_b = 8'hFF; carry_in = 0;
      check(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "PASS_FF");

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
