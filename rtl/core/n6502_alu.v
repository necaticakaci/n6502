// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Arithmetic Logic Unit
// ******************************************************

`include "n6502_consts.vh"

module n6502_alu (
   // Inputs
   input  wire [3:0] alu_op,       // ALU operation select
   input  wire [7:0] alu_a,        // Operand A
   input  wire [7:0] alu_b,        // Operand B
   input  wire       carry_in,     // Carry input (from P register)

   // Outputs
   output reg  [7:0] alu_out,      // ALU result
   output wire       carry_out,    // Carry flag output
   output wire       overflow_out, // Overflow flag output
   output wire       zero_out,     // Zero flag output
   output wire       negative_out  // Negative flag output
);

   wire [8:0] add_result;
   wire [7:0] add_b;
   wire       add_carry;

   // Unified adder
   assign add_b      = (alu_op == `ALU_SBC || alu_op == `ALU_CMP) ? ~alu_b : alu_b;
   assign add_carry  = (alu_op == `ALU_CMP) ? 1'b1 : carry_in;
   assign add_result = {1'b0, alu_a} + {1'b0, add_b} + {8'b0, add_carry};

   // ALU mux
   always @(*) begin
      alu_out = 8'h00;
      case (alu_op)
         `ALU_ADC, `ALU_SBC, `ALU_CMP: alu_out = add_result[7:0];
         `ALU_AND, `ALU_BIT:           alu_out = alu_a & alu_b;
         `ALU_ORA:                     alu_out = alu_a | alu_b;
         `ALU_EOR:                     alu_out = alu_a ^ alu_b;
         `ALU_ASL:                     alu_out = {alu_b[6:0], 1'b0};
         `ALU_LSR:                     alu_out = {1'b0, alu_b[7:1]};
         `ALU_ROL:                     alu_out = {alu_b[6:0], carry_in};
         `ALU_ROR:                     alu_out = {carry_in, alu_b[7:1]};
         `ALU_INC:                     alu_out = alu_b + 8'h01;
         `ALU_DEC:                     alu_out = alu_b - 8'h01;
         `ALU_PASS:                    alu_out = alu_b;
         default:                      alu_out = 8'h00;
      endcase
   end

   // ************************************************************************
   // Flag outputs
   // ************************************************************************
   assign zero_out     = (alu_out == 8'h00);
   assign negative_out = (alu_op == `ALU_BIT) ? alu_b[7] : alu_out[7];

   // Unified overflow: add_b is already ~alu_b for SBC, so one formula covers both
   assign overflow_out = (alu_op == `ALU_ADC || alu_op == `ALU_SBC)
                          ? (~(alu_a[7] ^ add_b[7]) & (alu_a[7] ^ add_result[7]))
                          : (alu_op == `ALU_BIT) ? alu_b[6]
                          : 1'b0;

   // CMP uses same add_result[8] as ADC/SBC merged into one group
   assign carry_out = (alu_op == `ALU_ADC || alu_op == `ALU_SBC || alu_op == `ALU_CMP)
                       ? add_result[8]
                       : (alu_op == `ALU_ASL || alu_op == `ALU_ROL)
                       ? alu_b[7]
                       : (alu_op == `ALU_LSR || alu_op == `ALU_ROR)
                       ? alu_b[0]
                       : carry_in;

endmodule
