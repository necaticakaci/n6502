// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Dormann Functional Testbench
//
// Runs the Klaus Dormann 6502 functional test suite
// against the n6502 core with trap detection and
// progress reporting.
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_dormann;

   // ****************************************************************
   // Configuration
   // ****************************************************************
   localparam TRAP_THRESHOLD   = 1000;          // cycles at same PC to trap
   localparam PROGRESS_BITS    = 26;            // 2^26 = ~67M cycles between progress
   localparam SUCCESS_PC       = 16'h336D;      // Dormann success trap address
   localparam TIMEOUT_NS       = 5_000_000_000; // 500M cycles @ 100MHz

   // ****************************************************************
   // DUT Signals
   // ****************************************************************
   reg         clk;
   reg         rst_n;
   wire [15:0] bus_addr;
   wire [ 7:0] bus_wdata;
   wire [ 7:0] bus_rdata;
   wire        bus_we;
   wire        bus_stb;
   wire        bus_ack;
   reg         irq_n;
   reg         nmi_n;
   wire [15:0] dbg_pc;
   wire [ 7:0] dbg_a;
   wire [ 7:0] dbg_x;
   wire [ 7:0] dbg_y;
   wire [ 7:0] dbg_sp;
   wire [ 7:0] dbg_p;

   // ****************************************************************
   // 64KB System Memory
   // ****************************************************************
   reg [7:0] memory [0:65535];

   // ****************************************************************
   // DUT
   // ****************************************************************
   n6502_core uut (
      .clk        (clk),
      .rst_n      (rst_n),
      .bus_addr   (bus_addr),
      .bus_wdata  (bus_wdata),
      .bus_rdata  (bus_rdata),
      .bus_we     (bus_we),
      .bus_stb    (bus_stb),
      .bus_ack    (bus_ack),
      .irq_n      (irq_n),
      .nmi_n      (nmi_n),
      .dbg_pc     (dbg_pc),
      .dbg_a      (dbg_a),
      .dbg_x      (dbg_x),
      .dbg_y      (dbg_y),
      .dbg_sp     (dbg_sp),
      .dbg_p      (dbg_p)
   );

   // ****************************************************************
   // Clock (100 MHz)
   // ****************************************************************
   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   // ****************************************************************
   // Reset & Interrupts
   // ****************************************************************
   initial begin
      rst_n = 0;
      irq_n = 1;
      nmi_n = 1;
      #100;
      rst_n = 1;
   end

   // ****************************************************************
   // Memory Init
   // ****************************************************************
   initial begin
      $readmemh("test/dormann/6502_functional_test.vhex", memory);
      // Override reset vector to point to test start ($0400)
      memory[16'hFFFC] = 8'h00;
      memory[16'hFFFD] = 8'h04;
   end

   // ****************************************************************
   // Bus Memory Responder
   // ****************************************************************
   assign bus_ack   = bus_stb;
   assign bus_rdata = memory[bus_addr];

   always @(posedge clk) begin
      if (rst_n && bus_stb && bus_we)
         memory[bus_addr] <= bus_wdata;
   end

   // ****************************************************************
   // Monitoring & Trap Detection
   // ****************************************************************
   reg [31:0] cycle_count;
   reg [15:0] trap_pc;
   reg [31:0] trap_count;
   reg [ 7:0] last_test_num;

   always @(posedge clk) begin
      if (!rst_n) begin
         cycle_count   <= 0;
         trap_pc       <= 16'hFFFF;
         trap_count    <= 0;
         last_test_num <= 8'hFF;
      end else begin
         cycle_count <= cycle_count + 1;

         // *** Success Detection ***
         if (dbg_pc == SUCCESS_PC) begin
            $display("");
            $display("****************************************");
            $display(" [PASS] KLAUS DORMANN 6502 TEST SUITE");
            $display("****************************************");
            $display(" Cycles:    %0d", cycle_count);
            $display(" CPU State: A=%02X X=%02X Y=%02X SP=%02X P=%02X",
                      dbg_a, dbg_x, dbg_y, dbg_sp, dbg_p);
            $display("****************************************");
            $finish;
         end

         // *** Self-Loop Trap Detection ***
         if (dbg_pc == trap_pc) begin
            trap_count <= trap_count + 1;
            if (trap_count == TRAP_THRESHOLD) begin
               $display("");
               $display("****************************************");
               $display(" [FAIL] CPU Trapped at PC = $%04X", dbg_pc);
               $display("****************************************");
               $display(" Cycles:    %0d", cycle_count);
               $display(" Test #:    $%02X", memory[16'h0200]);
               $display(" Opcode:    %02X %02X %02X",
                         memory[dbg_pc], memory[dbg_pc+1], memory[dbg_pc+2]);
               $display(" CPU State: A=%02X X=%02X Y=%02X SP=%02X P=%02X",
                         dbg_a, dbg_x, dbg_y, dbg_sp, dbg_p);
               $display("----------------------------------------");
               $display(" Stack (SP+1..SP+8): %02X %02X %02X %02X %02X %02X %02X %02X",
                         memory[{8'h01, dbg_sp+8'd1}], memory[{8'h01, dbg_sp+8'd2}],
                         memory[{8'h01, dbg_sp+8'd3}], memory[{8'h01, dbg_sp+8'd4}],
                         memory[{8'h01, dbg_sp+8'd5}], memory[{8'h01, dbg_sp+8'd6}],
                         memory[{8'h01, dbg_sp+8'd7}], memory[{8'h01, dbg_sp+8'd8}]);
               $display(" ZP Test Vars: $0D=%02X $0E=%02X $0F=%02X $10=%02X $11=%02X $12=%02X",
                         memory[8'h0D], memory[8'h0E], memory[8'h0F],
                         memory[8'h10], memory[8'h11], memory[8'h12]);
               $display("****************************************");
               $display(" Check 6502_functional_test.lst near PC=$%04X", dbg_pc);
               $display("****************************************");
               $finish;
            end
         end else begin
            trap_pc    <= dbg_pc;
            trap_count <= 0;
         end

         // *** Test Number Progress ***
         if (memory[16'h0200] != last_test_num) begin
            last_test_num <= memory[16'h0200];
            $display("[%0d] Test $%02X | PC=$%04X | A=%02X X=%02X Y=%02X P=%02X",
                      cycle_count, memory[16'h0200], dbg_pc, dbg_a, dbg_x, dbg_y, dbg_p);
         end

         // *** Periodic Progress (every ~67M cycles) ***
         if (cycle_count[PROGRESS_BITS-1:0] == {PROGRESS_BITS{1'b0}} && cycle_count > 0) begin
            $display("[%0dM cycles] PC=$%04X Test#=$%02X",
                      cycle_count / 1_000_000, dbg_pc, memory[16'h0200]);
         end
      end
   end

   // ****************************************************************
   // Timeout
   // ****************************************************************
   initial begin
      #TIMEOUT_NS;
      $display("");
      $display("****************************************");
      $display(" [TIMEOUT] Exceeded %0d ns (%0d cycles)",
                TIMEOUT_NS, cycle_count);
      $display("****************************************");
      $display(" Last PC: $%04X | Test#: $%02X", dbg_pc, memory[16'h0200]);
      $display("****************************************");
      $finish;
   end

endmodule
