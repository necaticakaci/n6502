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
   input  wire [15:0] bus_addr,
   output reg  [ 7:0] bus_rdata,
   input  wire        bus_stb,
   output reg         bus_ack
);

   // ROM Array
   reg [7:0] memory [0:(1<<ADDR_WIDTH)-1];

   // ROM Initialization
   initial begin
      if (INIT_FILE != "") begin
         $readmemh(INIT_FILE, memory);
      end else begin
         memory[(1<<ADDR_WIDTH)-4] = 8'h00; // Reset Vector Low  ($00)
         memory[(1<<ADDR_WIDTH)-3] = 8'h80; // Reset Vector High ($80 -> $8000)
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
