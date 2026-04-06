// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// SoC Testbench
//
// Verifies the SoC integration by running a blinky
// test program and monitoring GPIO output changes.
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_soc;

   // ****************************************************************
   // DUT Signals
   // ****************************************************************
   reg        clk;
   reg        rst_n;
   wire [7:0] gpio_out;
   reg  [7:0] gpio_in;

   // ****************************************************************
   // DUT
   // ****************************************************************
   n6502_soc uut (
      .clk      (clk),
      .rst_n    (rst_n),
      .gpio_in  (gpio_in),
      .gpio_out (gpio_out)
   );

   // Override the ROM INIT_FILE parameter to load our blinky hex
   defparam uut.u_rom.INIT_FILE = "test/programs/blinky.hex";

   // ****************************************************************
   // Clock (100 MHz)
   // ****************************************************************
   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   // ****************************************************************
   // Test Stimulus
   // ****************************************************************
   initial begin
      `ifdef DUMP_VCD
      $dumpfile("build/tb_n6502_soc.vcd");
      $dumpvars(0, tb_n6502_soc);
      `endif

      // Initialization
      rst_n   = 0;
      gpio_in = 8'h00;

      $display("****************************************");
      $display(" n6502 SoC Testbench");
      $display("****************************************");

      #20 rst_n = 1;
      $display("Time %t: Reset released, SoC booting...", $time);
   end

   // ****************************************************************
   // GPIO Monitor
   // ****************************************************************
   always @(posedge clk) begin
      if (rst_n) begin
         // Peek at the GPIO bus strobe exactly when writing
         if (uut.u_gpio.bus_stb && uut.u_gpio.bus_we && !uut.u_gpio.bus_ack) begin
            $display("Time %0t ns: [GPIO WRITE] Out pin changed to -> 0x%02X", $time, uut.u_gpio.bus_wdata);
         end
      end
   end
    
   // ****************************************************************
   // Completion Condition
   // ****************************************************************
   integer gpio_write_count = 0;
   always @(posedge clk) begin
      if (uut.u_gpio.bus_stb && uut.u_gpio.bus_we && uut.u_gpio.bus_ack) begin
         gpio_write_count = gpio_write_count + 1;
         if (gpio_write_count >= 10) begin
            $display("****************************************");
            $display(" 10 GPIO state changes observed.");
            $display(" *** ALL TESTS PASSED ***");
            $display("****************************************");
            $finish;
         end
      end
   end

   // ****************************************************************
   // Timeout
   // ****************************************************************
   initial begin
      #5000;
      $display("****************************************");
      $display(" [TIMEOUT] Simulation exceeded 5000 ns");
      $display("****************************************");
      $finish;
   end

endmodule
