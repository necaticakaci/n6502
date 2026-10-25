// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 SoC
// Top level System on Chip
// ******************************************************

module n6502_soc (
   input  wire clk,
   input  wire rst_n,

   input  wire [7:0] gpio_in,
   output wire [7:0] gpio_out
);

   // ************************************************************************
   // CPU Core
   // ************************************************************************
   wire [15:0] cpu_addr;
   wire [ 7:0] cpu_wdata;
   wire [ 7:0] cpu_rdata;
   wire        cpu_we;
   wire        cpu_stb;
   wire        cpu_ack;
    
   // Interrupt lines tied to inactive for now
   wire irq_n = 1'b1;
   wire nmi_n = 1'b1;

   n6502_core u_cpu (
      .clk        (clk),
      .rst_n      (rst_n),
      .bus_addr   (cpu_addr),
      .bus_wdata  (cpu_wdata),
      .bus_rdata  (cpu_rdata),
      .bus_we     (cpu_we),
      .bus_stb    (cpu_stb),
      .bus_ack    (cpu_ack),
      .irq_n      (irq_n),
      .nmi_n      (nmi_n),
      /* verilator lint_off PINCONNECTEMPTY */
      .dbg_pc     (),
      .dbg_a      (),
      .dbg_x      (),
      .dbg_y      (),
      .dbg_sp     (),
      .dbg_p      (),
      .dbg_illegal()
      /* verilator lint_on PINCONNECTEMPTY */
   );

   // ************************************************************************
   // Address Decoder
   // 0x0000 - 0x3FFF : RAM (16 KB)
   // 0x8000 - 0x8000 : GPIO Out (1 Byte)
   // 0xE000 - 0xFFFF : ROM (8 KB)
   // ************************************************************************
   wire ram_sel  = (cpu_addr < 16'h4000);
   wire rom_sel  = (cpu_addr >= 16'hE000);
   wire gpio_sel = (cpu_addr == 16'h8000);
   wire none_sel = ~(ram_sel | rom_sel | gpio_sel);

   wire ram_stb  = cpu_stb & ram_sel;
   wire rom_stb  = cpu_stb & rom_sel;
   wire gpio_stb = cpu_stb & gpio_sel;

   wire [7:0] ram_rdata;
   wire [7:0] rom_rdata;
   wire [7:0] gpio_rdata;
   wire       ram_ack;
   wire       rom_ack;
   wire       gpio_ack;

   // MUX Read Data
   assign cpu_rdata = ram_sel  ? ram_rdata :
                      rom_sel  ? rom_rdata :
                      gpio_sel ? gpio_rdata :
                      8'hEA; // Return NOP ($EA) for unmapped memory space

   // MUX Acknowledge
   // Unmapped space acks immediately so the CPU never stalls on it
   assign cpu_ack = (ram_sel & ram_ack) |
                    (rom_sel & rom_ack) |
                    (gpio_sel & gpio_ack) |
                    (none_sel & cpu_stb);

   // ************************************************************************
   // RAM Module (16 KB)
   // ************************************************************************
   ram #(
      .ADDR_WIDTH(14)
   ) u_ram (
      .clk        (clk),
      .rst_n      (rst_n),
      .bus_addr   (cpu_addr),
      .bus_wdata  (cpu_wdata),
      .bus_rdata  (ram_rdata),
      .bus_we     (cpu_we),
      .bus_stb    (ram_stb),
      .bus_ack    (ram_ack)
   );

   // ************************************************************************
   // ROM Module (8 KB)
   // ************************************************************************
   rom #(
      .ADDR_WIDTH(13),
      .INIT_FILE ("") // Testbench or Synth script sets this
   ) u_rom (
      .clk        (clk),
      .rst_n      (rst_n),
      .bus_addr   (cpu_addr),
      .bus_rdata  (rom_rdata),
      .bus_stb    (rom_stb),
      .bus_ack    (rom_ack)
   );

   // ************************************************************************
   // GPIO Module
   // ************************************************************************
   gpio u_gpio (
      .clk        (clk),
      .rst_n      (rst_n),
      .bus_addr   (cpu_addr),
      .bus_wdata  (cpu_wdata),
      .bus_rdata  (gpio_rdata),
      .bus_we     (cpu_we),
      .bus_stb    (gpio_stb),
      .bus_ack    (gpio_ack),
      .gpio_in    (gpio_in),
      .gpio_out   (gpio_out)
   );

endmodule
