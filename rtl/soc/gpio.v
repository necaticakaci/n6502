// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 SoC
// General Purpose Input/Output Peripheral
// ******************************************************

module gpio (
   input  wire        clk,
   input  wire        rst_n,

   // Slave Interface
   /* verilator lint_off UNUSEDSIGNAL */
   input  wire [15:0] bus_addr,  // Single register, fully decoded by the SoC
   /* verilator lint_on UNUSEDSIGNAL */
   input  wire [ 7:0] bus_wdata,
   output reg  [ 7:0] bus_rdata,
   input  wire        bus_we,
   input  wire        bus_stb,
   output reg         bus_ack,

   // External GPIO Pins
   input  wire [ 7:0] gpio_in,
   output reg  [ 7:0] gpio_out
);

   always @(posedge clk) begin
      if (!rst_n) begin
         gpio_out  <= 8'h00;
         bus_ack   <= 1'b0;
         bus_rdata <= 8'h00;
      end else begin
         bus_ack <= 1'b0;
         if (bus_stb && !bus_ack) begin
            bus_ack <= 1'b1;
            if (bus_we) begin
               gpio_out <= bus_wdata;
            end else begin
               bus_rdata <= gpio_in;
            end
         end
      end
   end

endmodule
