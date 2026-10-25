// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Core Testbench
//
// Functional test covering addressing modes, stack
// operations, subroutines, branches, interrupts
// (BRK, IRQ, NMI) and RMW instructions.
// ******************************************************

`timescale 1ns / 1ps

module tb_n6502_core;

   // ****************************************************************
   // DUT Signals
   // ****************************************************************
   reg         clk;
   reg         rst_n;

   wire [15:0] bus_addr;
   wire [ 7:0] bus_wdata;
   reg  [ 7:0] bus_rdata;
   wire        bus_we;
   wire        bus_stb;
   reg         bus_ack;

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
   // Memory Map
   // ****************************************************************
   // $0000 - $00FF : Zero Page RAM
   // $0100 - $01FF : Stack RAM
   // $0200 - $02FF : General RAM
   // $8000 - $FFFF : R/O ROM (Test Program)

   reg [7:0] zp_ram [0:255];
   reg [7:0] stk_ram[0:255];
   reg [7:0] wk_ram [0:255];

   integer i;
   initial begin
      for (i = 0; i < 256; i = i + 1) begin
         zp_ram[i]  = 8'h00;
         stk_ram[i] = 8'h00;
         wk_ram[i]  = 8'h00;
      end
      // Seed some data for indirect addressing pointers
      zp_ram[8'h10] = 8'h00; 
      zp_ram[8'h11] = 8'h02; // Pointer to $0200

      zp_ram[8'h50] = 8'h20; // Another pointer to $0220
      zp_ram[8'h51] = 8'h02; 
   end

   // ****************************************************************
   // Bus Memory Responder
   // ****************************************************************
   always @(posedge clk) begin
      if (!rst_n) begin
         bus_ack   <= 1'b0;
         bus_rdata <= 8'hEA; // NOP default

      end else begin
         bus_ack <= 1'b0; // Default off

         if (bus_stb && !bus_ack) begin
            bus_ack <= 1'b1;

               if (bus_we) begin
                  // Write
                  if (bus_addr[15:8] == 8'h00) begin
                     zp_ram[bus_addr[7:0]] <= bus_wdata;
                     $display("Time %t: ZP Write to %04X -> %02X", $time, bus_addr, bus_wdata);
                  end else if (bus_addr[15:8] == 8'h01) begin
                     stk_ram[bus_addr[7:0]] <= bus_wdata;
                     $display("Time %t: STACK Write to %04X -> %02X", $time, bus_addr, bus_wdata);
                  end else if (bus_addr[15:8] == 8'h02) begin
                     wk_ram[bus_addr[7:0]] <= bus_wdata;
                     $display("Time %t: WK Write to %04X -> %02X", $time, bus_addr, bus_wdata);
                  end else if (bus_addr[15:8] >= 8'h80) begin
                     $display("Time %t: ROM Write Attempt to %04X -> %02X", $time, bus_addr, bus_wdata);
                  end
               end else begin
                  // Read
                  if (bus_addr[15:8] == 8'h00) begin
                     bus_rdata <= zp_ram[bus_addr[7:0]];
                  end else if (bus_addr[15:8] == 8'h01) begin
                     bus_rdata <= stk_ram[bus_addr[7:0]];
                  end else if (bus_addr[15:8] == 8'h02) begin
                     bus_rdata <= wk_ram[bus_addr[7:0]];
                  end else begin
                     case (bus_addr)
                        16'hFFFC: bus_rdata <= 8'h00; // Reset Vector Low
                        16'hFFFD: bus_rdata <= 8'h80; // Reset Vector High

                        16'hFFFA: bus_rdata <= 8'h50; // NMI Vector Low ($8050)
                        16'hFFFB: bus_rdata <= 8'h80; // NMI Vector High

                        16'hFFFE: bus_rdata <= 8'h60; // IRQ/BRK Vector Low ($8060)
                        16'hFFFF: bus_rdata <= 8'h80; // IRQ/BRK Vector High

                        // User Program at 0x8000
                        16'h8000: bus_rdata <= 8'hA9; // LDA #$55        (A = $55)
                        16'h8001: bus_rdata <= 8'h55; // $55

                        16'h8002: bus_rdata <= 8'h8D; // STA $0205       (ABS)
                        16'h8003: bus_rdata <= 8'h05; // $05
                        16'h8004: bus_rdata <= 8'h02; // $02

                        16'h8005: bus_rdata <= 8'hA2; // LDX #$03        (X = $03)
                        16'h8006: bus_rdata <= 8'h03; // $03

                        16'h8007: bus_rdata <= 8'h95; // STA $10,X       (ZP,X = $13 -> $55)
                        16'h8008: bus_rdata <= 8'h10; // $10

                        16'h8009: bus_rdata <= 8'hA0; // LDY #$04        (Y = $04)
                        16'h800A: bus_rdata <= 8'h04; // $04

                        16'h800B: bus_rdata <= 8'h99; // STA $0210,Y     (ABS,Y = $0214 -> $55)
                        16'h800C: bus_rdata <= 8'h10; // $10
                        16'h800D: bus_rdata <= 8'h02; // $02

                        16'h800E: bus_rdata <= 8'h81; // STA ($10,X)     (IZX: ptr at $13/$14 = $55/$00 -> $0055 = $55)
                        16'h800F: bus_rdata <= 8'h10; // $10

                        16'h8010: bus_rdata <= 8'h91; // STA ($50),Y     (IZY: ptr at $50 = $20, $51 = $02 -> $0220 + Y = $0224 -> $55)
                        16'h8011: bus_rdata <= 8'h50; // $50

                        16'h8012: bus_rdata <= 8'h6C; // JMP ($0226)    (IND: ptr at $0226/$0227 contains $8015)
                        16'h8013: bus_rdata <= 8'h26; // $26
                        16'h8014: bus_rdata <= 8'h02; // $02

                        16'h8015: bus_rdata <= 8'hA9; // LDA #$AA        (A = $AA) landed here!
                        16'h8016: bus_rdata <= 8'hAA; // $AA

                        // Stack tests
                        16'h8017: bus_rdata <= 8'h48; // PHA           (Push A=$AA to stack)
                        16'h8018: bus_rdata <= 8'h08; // PHP           (Push P.  B-flag set in pushed value)

                        16'h8019: bus_rdata <= 8'hA9; // LDA #$00        (A = $00)
                        16'h801A: bus_rdata <= 8'h00; // $00

                        16'h801B: bus_rdata <= 8'h68; // PLA           (Pull P from stack into A just to check. It will be the status, e.g. 10110100)

                        16'h801C: bus_rdata <= 8'h68; // PLA           (Pull original A=$AA back from stack)

                        // Logic / RMW test
                        16'h801D: bus_rdata <= 8'h49; // EOR #$0F        (A = $AA ^ $0F = $A5)
                        16'h801E: bus_rdata <= 8'h0F; // $0F

                        16'h801F: bus_rdata <= 8'h85; // STA $42         (ZP[$42] = $A5)
                        16'h8020: bus_rdata <= 8'h42; // $42

                        16'h8021: bus_rdata <= 8'h06; // ASL $42         (ZP[$42] = $A5 << 1 = $4A, C=1)
                        16'h8022: bus_rdata <= 8'h42; // $42

                        16'h8023: bus_rdata <= 8'h20; // JSR $8040       (Jump to subroutine)
                        16'h8024: bus_rdata <= 8'h40; // $40
                        16'h8025: bus_rdata <= 8'h80; // $80

                        16'h8026: bus_rdata <= 8'hA2; // LDX #$01        (Returned from JSR, X = 1)
                        16'h8027: bus_rdata <= 8'h01; // $01

                        16'h8028: bus_rdata <= 8'hE8; // INX             (X = 2)
                        16'h8029: bus_rdata <= 8'hE0; // CPX #$02        (Compare X with 2)
                        16'h802A: bus_rdata <= 8'h02; // $02

                        16'h802B: bus_rdata <= 8'hF0; // BEQ +$03        (Branch IF Equal to $8030)
                        16'h802C: bus_rdata <= 8'h03; // +$03 (PC at $802D when reading offset. Target = $802D + $03 = $8030)

                        16'h802D: bus_rdata <= 8'hA2; // LDX #$FF        (Should skip this if BEQ works)
                        16'h802E: bus_rdata <= 8'hFF; // $FF
                        16'h802F: bus_rdata <= 8'hEA; // NOP

                        16'h8030: bus_rdata <= 8'hEA; // NOP             (Target of BEQ)
                        16'h8031: bus_rdata <= 8'hAA; // TAX             (X gets A ($A5))

                        // ************************************************
                        // INTERRUPTS
                        // ************************************************
                        16'h8032: bus_rdata <= 8'h00; // BRK             (Software Interrupt -> pushes PC+2 ($8034), P(B=1) -> jumps $8060)
                        16'h8033: bus_rdata <= 8'hEA; // Padding byte

                        16'h8034: bus_rdata <= 8'h58; // CLI             (Clear Interrupt Disable so IRQ works)

                        16'h8035: bus_rdata <= 8'hEA; // NOP             (Wait for IRQ)
                        16'h8036: bus_rdata <= 8'hEA; // NOP

                        // Returned from IRQ.
                        // Testbench will drop `nmi_n` to 0. (NMI works even if I=1)
                        16'h8037: bus_rdata <= 8'hEA; // NOP             (Wait for NMI)
                        16'h8038: bus_rdata <= 8'hEA; // NOP

                        // Returned from NMI.
                        16'h8039: bus_rdata <= 8'hA9; // LDA #$DD        (End of test)
                        16'h803A: bus_rdata <= 8'hDD; // $DD

                        16'h803B: bus_rdata <= 8'h02; // Illegal opcode  (Core halts, dbg_illegal = 1)

                        // ************************************************
                        // SUBROUTINE AT $8040
                        // ************************************************
                        16'h8040: bus_rdata <= 8'hA9; // LDA #$CC        (A = $CC)
                        16'h8041: bus_rdata <= 8'hCC; // $CC
                        16'h8042: bus_rdata <= 8'h60; // RTS             (Return to 8025 + 1 = 8026)

                        // ************************************************
                        // NMI ISR AT $8050
                        // ************************************************
                        16'h8050: bus_rdata <= 8'hA2; // LDX #$55        (X = $55)
                        16'h8051: bus_rdata <= 8'h55; // $55
                        16'h8052: bus_rdata <= 8'h40; // RTI             (Return from Interrupt)

                        // ************************************************
                        // IRQ / BRK ISR AT $8060
                        // ************************************************
                        16'h8060: bus_rdata <= 8'hA0; // LDY #$66        (Y = $66)
                        16'h8061: bus_rdata <= 8'h66; // $66
                        16'h8062: bus_rdata <= 8'h40; // RTI             (Return from Interrupt)
                        
                        default:  bus_rdata <= 8'hEA; // NOP everywhere else
                     endcase
                  end
               end
         end
      end
   end

   // Seed pointer for JMP ($0226)
   initial begin
      wk_ram[8'h26] = 8'h15; // Low byte  (8015)
      wk_ram[8'h27] = 8'h80; // High byte (8015)
   end

   // ****************************************************************
   // ASL Carry Capture
   // ****************************************************************
   // CPX and RTI overwrite C later, so the final P cannot show the ASL
   // result. Sample C once the JSR after ASL $42 has been fetched.
   reg asl_carry;
   initial begin
      asl_carry = 1'b0;
      wait (dbg_pc == 16'h8023); // ASL decoded, PC at JSR
      wait (dbg_pc != 16'h8023); // JSR fetched, ASL complete
      asl_carry = dbg_p[0];
   end

   // ****************************************************************
   // Check Task
   // ****************************************************************
   task check;
      input        cond;
      input [255:0] pass_msg;
      input [255:0] fail_msg;
      begin
         if (cond) begin
            $display("PASS: %0s", pass_msg);
            pass_count = pass_count + 1;
         end else begin
            $display("FAIL: %0s", fail_msg);
            fail_count = fail_count + 1;
         end
      end
   endtask

   // ****************************************************************
   // Test Stimulus
   // ****************************************************************
   initial begin
      `ifdef DUMP_VCD
      $dumpfile("build/tb_n6502_core.vcd");
      $dumpvars(0, tb_n6502_core);
      `endif

      pass_count = 0;
      fail_count = 0;

      rst_n = 0;
      irq_n = 1;
      nmi_n = 1;

      $display("****************************************");
      $display(" n6502 Core Testbench");
      $display("****************************************");

      #20 rst_n = 1;
        
      // Wait for reset fetch ($FFFC and $FFFD)
      wait(dbg_pc == 16'h8000);
      $display("Reset completed, PC = %04X", dbg_pc);

      // Wait for IRQ instruction pad
      wait(dbg_pc == 16'h8035);
      #40 irq_n = 0; // Trigger IRQ
      #40 irq_n = 1; // Release

      // Wait for NMI instruction pad
      wait(dbg_pc == 16'h8037);
      #40 nmi_n = 0; // Trigger NMI
      #40 nmi_n = 1; // Release

      // Wait for end of test program at $803B
      wait(dbg_pc == 16'h803B);
      $display("Test complete.");
      $display("Final state: A=%02X, X=%02X, Y=%02X, SP=%02X, P=%02X", dbg_a, dbg_x, dbg_y, dbg_sp, dbg_p);

      // ************************************************************
      // Assertions
      // ************************************************************
      check(wk_ram[8'h05] == 8'h55,
            "STA ABS: WK_RAM[$0205] = $55",
            "STA ABS: WK_RAM[$0205] != $55");

      check(zp_ram[8'h13] == 8'h55,
            "STA ZP,X: ZP_RAM[$0013] = $55",
            "STA ZP,X: ZP_RAM[$0013] != $55");

      check(wk_ram[8'h14] == 8'h55,
            "STA ABS,Y: WK_RAM[$0214] = $55",
            "STA ABS,Y: WK_RAM[$0214] != $55");

      check(zp_ram[8'h55] == 8'h55,
            "STA (IND,X): ZP_RAM[$0055] = $55",
            "STA (IND,X): ZP_RAM[$0055] != $55");

      check(wk_ram[8'h24] == 8'h55,
            "STA (IND),Y: WK_RAM[$0224] = $55",
            "STA (IND),Y: WK_RAM[$0224] != $55");

      // A is finally set to $DD by LDA #$DD at $8039 (end of test marker)
      check(dbg_a == 8'hDD,
            "End marker: A = $DD",
            "End marker: A != $DD");

      check(dbg_x == 8'h55,
            "NMI Vector: X = $55",
            "NMI Vector: X != $55");

      check(dbg_y == 8'h66,
            "IRQ/BRK Vector: Y = $66",
            "IRQ/BRK Vector: Y != $66");

      check(zp_ram[8'h42] == 8'h4A,
            "ASL ZP: ZP_RAM[$42] = $4A",
            "ASL ZP: ZP_RAM[$42] != $4A");

      check(asl_carry == 1'b1,
            "ASL Carry: C = 1",
            "ASL Carry: C != 1");

      // Illegal opcode at $803B: core halts with PC past the opcode
      repeat (20) @(posedge clk);
      check(dbg_illegal && dbg_pc == 16'h803C,
            "Illegal opcode: halted, flagged",
            "Illegal opcode: not flagged");

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

      #20 $finish;
   end

endmodule
