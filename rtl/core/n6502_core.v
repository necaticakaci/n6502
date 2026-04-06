// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Top Level Core
// ******************************************************

module n6502_core (
   input  wire        clk,
   input  wire        rst_n,

   // CPU Master Interface
   output wire [15:0] bus_addr,
   output wire [ 7:0] bus_wdata,
   input  wire [ 7:0] bus_rdata,
   output wire        bus_we,
   output wire        bus_stb,
   input  wire        bus_ack,

   // Interrupt Inputs
   input  wire        irq_n,
   input  wire        nmi_n,

   // Debug Outputs
   output wire [15:0] dbg_pc,
   output wire [ 7:0] dbg_a,
   output wire [ 7:0] dbg_x,
   output wire [ 7:0] dbg_y,
   output wire [ 7:0] dbg_sp,
   output wire [ 7:0] dbg_p
);

   // ************************************************************************
   // Internal Wiring
   // ************************************************************************

   // Decoder <-> Control
   wire [ 7:0] dec_opcode;
   wire [ 3:0] dec_addr_mode;
   wire [ 3:0] dec_alu_op;
   wire [ 2:0] dec_alu_src_a;
   wire [ 2:0] dec_reg_src;
   wire [ 2:0] dec_reg_dst;
   wire        dec_mem_read;
   wire        dec_mem_write;
   wire [ 7:0] dec_flag_mask;
   wire        dec_is_branch;
   wire        dec_is_stack;
   wire        dec_is_jump;
   wire        dec_is_jsr;
   wire        dec_is_return;
   wire        dec_is_brk;
   wire        dec_illegal;

   // ALU <-> Control
   wire [ 7:0] alu_a;
   wire [ 7:0] alu_b;
   wire [ 3:0] alu_op;
   wire        alu_carry_in;
   wire [ 7:0] alu_out;
   wire        alu_carry_out;
   wire        alu_overflow_out;
   wire        alu_zero_out;
   wire        alu_negative_out;

   // ************************************************************************
   // Module Instantiations
   // ************************************************************************

   // Opcode Decoder
   n6502_decoder u_decoder (
      .opcode        (dec_opcode),
      .addr_mode     (dec_addr_mode),
      .alu_op        (dec_alu_op),
      .alu_src_a     (dec_alu_src_a),
      .reg_src       (dec_reg_src),
      .reg_dst       (dec_reg_dst),
      .mem_read      (dec_mem_read),
      .mem_write     (dec_mem_write),
      .flag_mask     (dec_flag_mask),
      .is_branch     (dec_is_branch),
      .is_stack      (dec_is_stack),
      .is_jump       (dec_is_jump),
      .is_jsr        (dec_is_jsr),
      .is_return     (dec_is_return),
      .is_brk        (dec_is_brk),
      .illegal       (dec_illegal)
   );

   // Arithmetic Logic Unit
   n6502_alu u_alu (
      .alu_op           (alu_op),
      .alu_a            (alu_a),
      .alu_b            (alu_b),
      .carry_in         (alu_carry_in),

      .alu_out          (alu_out),
      .carry_out        (alu_carry_out),
      .overflow_out     (alu_overflow_out),
      .zero_out         (alu_zero_out),
      .negative_out     (alu_negative_out)
   );

   // Control Unit
   n6502_control u_control (
      .clk                 (clk),
      .rst_n               (rst_n),

      .bus_addr            (bus_addr),
      .bus_wdata           (bus_wdata),
      .bus_rdata           (bus_rdata),
      .bus_we              (bus_we),
      .bus_stb             (bus_stb),
      .bus_ack             (bus_ack),

      .alu_a               (alu_a),
      .alu_b               (alu_b),
      .alu_op              (alu_op),
      .alu_carry_in        (alu_carry_in),
      .alu_out             (alu_out),
      .alu_carry_out       (alu_carry_out),
      .alu_overflow_out    (alu_overflow_out),
      .alu_zero_out        (alu_zero_out),
      .alu_negative_out    (alu_negative_out),

      .dec_opcode          (dec_opcode),
      .dec_addr_mode       (dec_addr_mode),
      .dec_alu_op          (dec_alu_op),
      .dec_alu_src_a       (dec_alu_src_a),
      .dec_reg_src         (dec_reg_src),
      .dec_reg_dst         (dec_reg_dst),
      .dec_mem_read        (dec_mem_read),
      .dec_mem_write       (dec_mem_write),
      .dec_flag_mask       (dec_flag_mask),
      .dec_is_branch       (dec_is_branch),
      .dec_is_stack        (dec_is_stack),
      .dec_is_jump         (dec_is_jump),
      .dec_is_jsr          (dec_is_jsr),
      .dec_is_return       (dec_is_return),
      .dec_is_brk          (dec_is_brk),
      .dec_illegal         (dec_illegal),

      .irq_n               (irq_n),
      .nmi_n               (nmi_n),

      .dbg_pc              (dbg_pc),
      .dbg_a               (dbg_a),
      .dbg_x               (dbg_x),
      .dbg_y               (dbg_y),
      .dbg_sp              (dbg_sp),
      .dbg_p               (dbg_p)
   );

endmodule
