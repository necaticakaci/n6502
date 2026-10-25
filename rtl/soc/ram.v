// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 SoC
// BRAM mapped Synchronous RAM
// ******************************************************

module ram #(
   parameter ADDR_WIDTH = 14 // 16 KB default
)(
   input  wire        clk,
   input  wire        rst_n,

   // Slave Interface
   /* verilator lint_off UNUSEDSIGNAL */
   input  wire [15:0] bus_addr,  // Upper bits decoded by the SoC
   /* verilator lint_on UNUSEDSIGNAL */
   input  wire [ 7:0] bus_wdata,
   output reg  [ 7:0] bus_rdata,
   input  wire        bus_we,
   input  wire        bus_stb,
   output reg         bus_ack
);

   // RAM Array
   reg [7:0] memory [0:(1<<ADDR_WIDTH)-1];

   // Synchronous Read/Write with 1-cycle latency
   always @(posedge clk) begin
      if (!rst_n) begin
         bus_ack   <= 1'b0;
         bus_rdata <= 8'h00;
      end else begin
         bus_ack <= 1'b0;
         if (bus_stb && !bus_ack) begin
            bus_ack <= 1'b1;
            if (bus_we) begin
               memory[bus_addr[ADDR_WIDTH-1:0]] <= bus_wdata;
            end else begin
               bus_rdata <= memory[bus_addr[ADDR_WIDTH-1:0]];
            end
         end
      end
   end

endmodule
