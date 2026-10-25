// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Interrupt Testbench
//
// Regression for IRQ/NMI entry: plain IRQ, single NMI,
// and an NMI edge swept across every cycle of an IRQ
// entry (covers the vector-select race independent of
// input synchronizer latency). Every case runs on
// zero-wait and 1-wait-state memory.
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_irq;

   // ****************************************************************
   // Configuration
   // ****************************************************************
   localparam SETTLE_CYCLES = 300;       // time for ISRs to run and return
   localparam SWEEP_CYCLES  = 32;        // NMI offsets tried during IRQ entry
   localparam TIMEOUT_NS    = 2_000_000;

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
   wire        dbg_illegal;

   // ****************************************************************
   // Counters
   // ****************************************************************
   integer pass_count;
   integer fail_count;

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
      .dbg_p      (dbg_p),
      .dbg_illegal(dbg_illegal)
   );

   // ****************************************************************
   // Clock (100 MHz)
   // ****************************************************************
   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   // ****************************************************************
   // 64KB Memory: zero-wait or 1-wait-state responder
   // ****************************************************************
   reg [7:0] memory [0:65535];
   reg       wait_mode;  // 0: bus_ack = bus_stb, 1: registered ack
   reg       ack_r;
   reg [7:0] rdata_r;

   assign bus_ack   = wait_mode ? ack_r   : bus_stb;
   assign bus_rdata = wait_mode ? rdata_r : memory[bus_addr];

   always @(posedge clk) begin
      ack_r <= 1'b0;
      if (rst_n && bus_stb) begin
         if (!wait_mode) begin
            if (bus_we) memory[bus_addr] <= bus_wdata;
         end else if (!ack_r) begin
            ack_r <= 1'b1;
            if (bus_we) memory[bus_addr] <= bus_wdata;
            else        rdata_r <= memory[bus_addr];
         end
      end
   end

   // ****************************************************************
   // Program Load & Reset
   // ****************************************************************
   // $0400 : CLI ; JMP $0401
   // $0550 : NMI ISR  - INC $10 ; RTI
   // $0660 : IRQ ISR  - INC $11 ; RTI
   // $0560 : {NMI vector hi, IRQ vector lo}, only reached through a
   //         mixed vector - INC $12 ; RTI
   integer i;

   task setup;
      input mode;
      begin
         rst_n     = 0;
         irq_n     = 1;
         nmi_n     = 1;
         wait_mode = mode;

         for (i = 0; i < 65536; i = i + 1)
            memory[i] = 8'hEA;

         memory[16'hFFFA] = 8'h50; memory[16'hFFFB] = 8'h05; // NMI   -> $0550
         memory[16'hFFFC] = 8'h00; memory[16'hFFFD] = 8'h04; // RESET -> $0400
         memory[16'hFFFE] = 8'h60; memory[16'hFFFF] = 8'h06; // IRQ   -> $0660

         memory[16'h0400] = 8'h58;                           // CLI
         memory[16'h0401] = 8'h4C;                           // JMP $0401
         memory[16'h0402] = 8'h01;
         memory[16'h0403] = 8'h04;

         memory[16'h0550] = 8'hE6; memory[16'h0551] = 8'h10; // INC $10
         memory[16'h0552] = 8'h40;                           // RTI
         memory[16'h0660] = 8'hE6; memory[16'h0661] = 8'h11; // INC $11
         memory[16'h0662] = 8'h40;                           // RTI
         memory[16'h0560] = 8'hE6; memory[16'h0561] = 8'h12; // INC $12
         memory[16'h0562] = 8'h40;                           // RTI

         memory[16'h0010] = 8'h00;
         memory[16'h0011] = 8'h00;
         memory[16'h0012] = 8'h00;

         repeat (5) @(posedge clk);
         rst_n = 1;
         repeat (60) @(posedge clk); // reset vector, CLI, into main loop
      end
   endtask

   // ****************************************************************
   // Bus Observers
   // ****************************************************************
   // Both sample on negedge, so a stimulus change made right after
   // they return is seen by the core on the following posedge.

   // Wait for the n-th acked stack write (entry pushes PCH, PCL, P)
   task wait_stack_writes;
      input integer n;
      integer seen;
      begin
         seen = 0;
         while (seen < n) begin
            @(negedge clk);
            if (bus_stb && bus_ack && bus_we && bus_addr[15:8] == 8'h01)
               seen = seen + 1;
         end
      end
   endtask

   // Wait for an acked read of the given address
   task wait_read;
      input [15:0] addr;
      begin
         @(negedge clk);
         while (!(bus_stb && bus_ack && !bus_we && bus_addr == addr))
            @(negedge clk);
      end
   endtask

   // Short NMI low pulse, then let the ISRs finish
   task pulse_nmi_and_settle;
      begin
         nmi_n = 0;
         repeat (5) @(negedge clk);
         nmi_n = 1;
         repeat (SETTLE_CYCLES) @(posedge clk);
      end
   endtask

   // ****************************************************************
   // Checks
   // ****************************************************************
   // ISR run counts must match; also requires no mixed-vector entry,
   // a balanced stack and no illegal-opcode halt.
   function isr_ok;
      input [7:0] exp_nmi;
      input [7:0] exp_irq;
      begin
         isr_ok = memory[16'h0010] == exp_nmi && memory[16'h0011] == exp_irq &&
                  memory[16'h0012] == 8'h00 && dbg_sp == 8'hFD && !dbg_illegal;
      end
   endfunction

   task show_isr_state;
      begin
         $display("      NMI ISR=%0d IRQ ISR=%0d mixed=%0d SP=%02X illegal=%b",
                  memory[16'h0010], memory[16'h0011], memory[16'h0012],
                  dbg_sp, dbg_illegal);
      end
   endtask

   task check_isr;
      input [8*32-1:0] name;
      input [7:0]      exp_nmi;
      input [7:0]      exp_irq;
      begin
         if (isr_ok(exp_nmi, exp_irq)) begin
            $display("PASS: %0s", name);
            pass_count = pass_count + 1;
         end else begin
            $display("FAIL: %0s (expected NMI ISR=%0d IRQ ISR=%0d)", name, exp_nmi, exp_irq);
            show_isr_state;
            fail_count = fail_count + 1;
         end
      end
   endtask

   // ****************************************************************
   // Scenarios
   // ****************************************************************
   integer offset;
   integer sweep_fails;

   task run_scenarios;
      input mode;
      begin
         // IRQ alone, held until entry starts
         setup(mode);
         @(negedge clk) irq_n = 0;
         wait_stack_writes(1);
         irq_n = 1;
         repeat (SETTLE_CYCLES) @(posedge clk);
         check_isr("IRQ only", 8'd0, 8'd1);

         // Single NMI edge: taken exactly once
         setup(mode);
         @(negedge clk);
         pulse_nmi_and_settle;
         check_isr("NMI only", 8'd1, 8'd0);

         // NMI edge at every cycle offset from IRQ assertion. Whatever the
         // offset (before, during or after the vector fetch), both ISRs run
         // exactly once and no mixed vector is taken. IRQ stays asserted
         // until its ISR starts, so an IRQ hijacked by NMI is retaken.
         sweep_fails = 0;
         for (offset = 0; offset < SWEEP_CYCLES; offset = offset + 1) begin
            setup(mode);
            @(negedge clk) irq_n = 0;
            fork
               begin
                  wait_read(16'h0660);
                  irq_n = 1;
               end
               begin
                  repeat (offset) @(negedge clk);
                  pulse_nmi_and_settle;
               end
            join
            if (isr_ok(8'd1, 8'd1)) begin
               pass_count = pass_count + 1;
            end else begin
               $display("FAIL: NMI %0d cycles after IRQ (expected NMI ISR=1 IRQ ISR=1)", offset);
               show_isr_state;
               fail_count  = fail_count + 1;
               sweep_fails = sweep_fails + 1;
            end
         end
         if (sweep_fails == 0)
            $display("PASS: NMI swept across IRQ entry (%0d offsets)", SWEEP_CYCLES);
      end
   endtask

   // ****************************************************************
   // Test Stimulus
   // ****************************************************************
   initial begin
      `ifdef DUMP_VCD
      $dumpfile("build/tb_n6502_irq.vcd");
      $dumpvars(0, tb_n6502_irq);
      `endif

      pass_count = 0;
      fail_count = 0;

      $display("****************************************");
      $display(" n6502 Interrupt Testbench");
      $display("****************************************");

      $display("Zero-wait memory (bus_ack = bus_stb)");
      run_scenarios(1'b0);

      $display("1-wait-state memory");
      run_scenarios(1'b1);

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

   // ****************************************************************
   // Timeout
   // ****************************************************************
   initial begin
      #TIMEOUT_NS;
      $display("****************************************");
      $display(" [TIMEOUT] Simulation exceeded %0d ns", TIMEOUT_NS);
      $display("****************************************");
      $finish;
   end

endmodule
