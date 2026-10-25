// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 SoC
// BRAM mapped Synchronous ROM
// ******************************************************

module rom #(
   parameter ADDR_WIDTH = 13, // 8 KB default
   parameter INIT_FILE  = ""
)(
   input  wire        clk,
   input  wire        rst_n,

   // Slave Interface
   /* verilator lint_off UNUSEDSIGNAL */
   input  wire [15:0] bus_addr,  // Upper bits decoded by the SoC
   /* verilator lint_on UNUSEDSIGNAL */
   output reg  [ 7:0] bus_rdata,
   input  wire        bus_stb,
   output reg         bus_ack
);

   // ROM Array
   reg [7:0] memory [0:(1<<ADDR_WIDTH)-1];

   // ROM holds the vectors, so it sits at the top of memory
   localparam [15:0] BASE_ADDR = 16'hFFFF << ADDR_WIDTH;

   // ROM Initialization
   initial begin
      if (INIT_FILE != "") begin
         $readmemh(INIT_FILE, memory);
      end else begin
         // No image: park the CPU in a JMP-to-self loop at the ROM base
         memory[0] = 8'h4C;                           // JMP BASE_ADDR
         memory[1] = BASE_ADDR[7:0];
         memory[2] = BASE_ADDR[15:8];
         memory[(1<<ADDR_WIDTH)-4] = BASE_ADDR[7:0];  // Reset Vector Low
         memory[(1<<ADDR_WIDTH)-3] = BASE_ADDR[15:8]; // Reset Vector High
      end
   end

   // Synchronous Read
   always @(posedge clk) begin
      if (!rst_n) begin
         bus_ack   <= 1'b0;
         bus_rdata <= 8'h00;
      end else begin
         bus_ack <= 1'b0;
         if (bus_stb && !bus_ack) begin
            bus_ack   <= 1'b1;
            bus_rdata <= memory[bus_addr[ADDR_WIDTH-1:0]];
         end
      end
   end

endmodule
