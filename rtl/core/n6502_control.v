// ******************************************************
// Copyright (C) 2026 Necati Çakacı
// Licensed under the Solderpad Hardware License v 2.1
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// n6502 CPU
// Control Unit
// ******************************************************

`include "n6502_consts.vh"

module n6502_control (
   input  wire        clk,
   input  wire        rst_n,

   // Master Bus Interface
   output reg  [15:0] bus_addr,
   output reg  [ 7:0] bus_wdata,
   input  wire [ 7:0] bus_rdata,
   output reg         bus_we,
   output reg         bus_stb,
   input  wire        bus_ack,

   // ALU Interface
   output reg  [ 7:0] alu_a,
   output reg  [ 7:0] alu_b,
   output reg  [ 3:0] alu_op,
   output reg         alu_carry_in,
   input  wire [ 7:0] alu_out,
   input  wire        alu_carry_out,
   input  wire        alu_overflow_out,
   input  wire        alu_zero_out,
   input  wire        alu_negative_out,

   // Decoder Interface
   output wire [ 7:0] dec_opcode,
   input  wire [ 3:0] dec_addr_mode,
   input  wire [ 3:0] dec_alu_op,
   input  wire [ 2:0] dec_alu_src_a,
   input  wire [ 2:0] dec_reg_src,
   input  wire [ 2:0] dec_reg_dst,
   input  wire        dec_mem_read,
   input  wire        dec_mem_write,
   /* verilator lint_off UNUSEDSIGNAL */
   input  wire [ 7:0] dec_flag_mask, // Bits [5:2] unused: B/D/I set by dedicated opcodes
   /* verilator lint_on UNUSEDSIGNAL */
   input  wire        dec_is_branch,
   input  wire        dec_is_stack,
   input  wire        dec_is_jump,
   input  wire        dec_is_jsr,
   input  wire        dec_is_return,
   input  wire        dec_is_brk,
   input  wire        dec_illegal,

   // Interrupts
   input  wire        irq_n,
   input  wire        nmi_n,

   // Debug Interface
   output wire [15:0] dbg_pc,
   output wire [ 7:0] dbg_a,
   output wire [ 7:0] dbg_x,
   output wire [ 7:0] dbg_y,
   output wire [ 7:0] dbg_sp,
   output wire [ 7:0] dbg_p,
   output wire        dbg_illegal
);

   // ****************************************************************
   // Register File
   // ****************************************************************
   reg [7:0]  reg_a, reg_x, reg_y, reg_sp;
   reg [15:0] reg_pc;
   reg [7:0]  reg_p;   // NV-BDIZC

   assign dbg_pc = reg_pc;
   assign dbg_a  = reg_a;
   assign dbg_x  = reg_x;
   assign dbg_y  = reg_y;
   assign dbg_sp = reg_sp;
   assign dbg_p  = reg_p;

   // ****************************************************************
   // Internal State
   // ****************************************************************
   reg [7:0]  opcode_reg;
   reg [7:0]  temp_data;
   reg [15:0] target_addr;
   reg [15:0] ptr_addr;

   // ****************************************************************
   // State Encoding
   // ****************************************************************
   localparam [4:0]
      S_RESET_0       = 5'd0,
      S_RESET_1       = 5'd1,
      S_FETCH         = 5'd2,
      S_DECODE        = 5'd3,
      S_FETCH_HI      = 5'd4,
      S_ADDR_CALC     = 5'd5,
      S_EXEC          = 5'd6,
      S_MEM_WRITE     = 5'd7,
      S_IND_LO        = 5'd8,
      S_IND_HI        = 5'd9,
      S_PUSH          = 5'd10,
      S_PULL_READ     = 5'd11,
      S_JSR_PUSH_PCL  = 5'd12,
      S_JSR_JUMP      = 5'd13,
      S_RET_P         = 5'd14,
      S_RET_PCL       = 5'd15,
      S_RET_PCH       = 5'd16,
      S_INT_PUSH_PCL  = 5'd17,
      S_INT_PUSH_P    = 5'd18,
      S_INT_VEC_LO    = 5'd19,
      S_INT_VEC_HI    = 5'd20,
      S_ERROR         = 5'd31;

   reg [4:0] state;

   // Halted on an illegal opcode (held until reset)
   assign dbg_illegal = (state == S_ERROR);

   // Decoder input: decode from the latched opcode only. S_FETCH uses no
   // decoder outputs, so a bus_rdata bypass would only lengthen paths.
   assign dec_opcode = opcode_reg;

   // ****************************************************************
   // Interrupt Tracking
   // ****************************************************************
   reg [1:0] nmi_sync, irq_sync; // 2-FF synchronizers, pins may be asynchronous
   reg nmi_last, nmi_pending, irq_pending, is_software_int;
   reg int_is_nmi; // Vector chosen for the current sequence, latched in S_INT_VEC_LO

   // Acknowledge in the same cycle the NMI vector high byte is taken,
   // so the next S_FETCH no longer sees the NMI as pending
   wire nmi_ack = (state == S_INT_VEC_HI) && bus_stb && bus_ack &&
                  bus_addr[0] && int_is_nmi;

   always @(posedge clk) begin
      if (!rst_n) begin
         nmi_sync    <= 2'b11;
         irq_sync    <= 2'b11;
         nmi_last    <= 1'b1;
         nmi_pending <= 1'b0;
         irq_pending <= 1'b0;
      end else begin
         nmi_sync <= {nmi_sync[0], nmi_n};
         irq_sync <= {irq_sync[0], irq_n};
         nmi_last <= nmi_sync[1];
         if (nmi_last && !nmi_sync[1])
            nmi_pending <= 1'b1; // A new edge wins over a simultaneous acknowledge
         else if (nmi_ack)
            nmi_pending <= 1'b0;
         irq_pending <= !irq_sync[1];
      end
   end

   // ****************************************************************
   // Branch Condition Logic
   // ****************************************************************
   reg  selected_flag;
   wire branch_taken;

   always @(*) begin
      case (opcode_reg[7:6])
         2'b00: selected_flag = reg_p[`FLAG_N];
         2'b01: selected_flag = reg_p[`FLAG_V];
         2'b10: selected_flag = reg_p[`FLAG_C];
         2'b11: selected_flag = reg_p[`FLAG_Z];
      endcase
   end

   assign branch_taken = selected_flag == opcode_reg[5];

   // ****************************************************************
   // Write Result and Update Flags
   // ****************************************************************
   task automatic write_result;
   begin
      if (dec_reg_dst == `REG_A)  reg_a  <= alu_out;
      if (dec_reg_dst == `REG_X)  reg_x  <= alu_out;
      if (dec_reg_dst == `REG_Y)  reg_y  <= alu_out;
      if (dec_reg_dst == `REG_SP) reg_sp <= alu_out;
      if (dec_reg_dst == `REG_P)  reg_p  <= {alu_out[7:6], 1'b1, reg_p[4], alu_out[3:0]};
   end
   endtask

   task automatic update_flags;
   begin
      if (dec_flag_mask[`FLAG_N]) reg_p[`FLAG_N] <= alu_negative_out;
      if (dec_flag_mask[`FLAG_Z]) reg_p[`FLAG_Z] <= alu_zero_out;
      if (dec_flag_mask[`FLAG_C]) reg_p[`FLAG_C] <= alu_carry_out;
      if (dec_flag_mask[`FLAG_V]) reg_p[`FLAG_V] <= alu_overflow_out;
   end
   endtask

   // Pre-launch a read from given address
   task automatic pre_read;
      input [15:0] addr;
   begin
      bus_addr <= addr;
      bus_stb  <= 1'b1;
      bus_we   <= 1'b0;
   end
   endtask

   // Pre-launch a write
   task automatic pre_write;
      input [15:0] addr;
      input [7:0]  data;
   begin
      bus_addr  <= addr;
      bus_wdata <= data;
      bus_stb   <= 1'b1;
      bus_we    <= 1'b1;
   end
   endtask

   // Pre-launch next opcode fetch (overlap pattern)
   task automatic pre_fetch_next;
   begin
      bus_addr <= reg_pc;
      bus_stb  <= 1'b1;
      bus_we   <= 1'b0;
   end
   endtask

   // JSR / BRK helpers
   wire [ 7:0] jsr_ret_pcl = reg_pc[7:0] - 8'h01; // Low byte of PC-1 (last JSR byte)
   wire [15:0] pc_plus_1   = reg_pc + 16'h0001;

   // Store data selection
   reg [7:0] store_data;
   always @(*) begin
      case (dec_reg_src)
         `REG_A:   store_data = reg_a;
         `REG_X:   store_data = reg_x;
         `REG_Y:   store_data = reg_y;
         default:  store_data = 8'h00;
      endcase
   end

   // ***********************************************************************=
   // FSM and Control Logic
   // ***********************************************************************=
   always @(posedge clk) begin
      if (!rst_n) begin
         state    <= S_RESET_0;
         reg_a    <= 8'h00;
         reg_x    <= 8'h00;
         reg_y    <= 8'h00;
         reg_sp   <= 8'hFD;
         reg_p    <= 8'h34;
         bus_stb  <= 1'b0;
         bus_we   <= 1'b0;
      end else begin
         case (state)

         // ****************************************************************
         // RESET
         // ****************************************************************
         S_RESET_0: begin
            // Pre-launch read from $FFFC
            pre_read(16'hFFFC);
            state <= S_RESET_1;
         end

         S_RESET_1: begin
            if (bus_stb && bus_ack) begin
               if (bus_addr == 16'hFFFC) begin
                  reg_pc[7:0] <= bus_rdata;
                  pre_read(16'hFFFD);
               end else begin
                  // $FFFD read complete
                  reg_pc[15:8] <= bus_rdata;
                  bus_addr     <= {bus_rdata, reg_pc[7:0]};
                  bus_stb      <= 1'b1;
                  bus_we       <= 1'b0;
                  state        <= S_FETCH;
               end
            end
         end

         // ****************************************************************
         // FETCH
         // ****************************************************************
         S_FETCH: begin
            if (bus_stb && bus_ack) begin
               // Check for pending interrupts before decoding
               if (nmi_pending || (irq_pending && !reg_p[`FLAG_I])) begin
                  // Interrupt hijack: drop opcode, pre-launch PCH push
                  is_software_int <= 1'b0;
                  pre_write({8'h01, reg_sp}, reg_pc[15:8]);
                  state           <= S_INT_PUSH_PCL;
               end else begin
                  // Latch opcode and advance PC
                  opcode_reg <= bus_rdata;
                  reg_pc     <= reg_pc + 1'b1;

                  // Pre-launch read from PC+1
                  bus_addr <= reg_pc + 1'b1;
                  bus_stb  <= 1'b1;
                  bus_we   <= 1'b0;
                  state    <= S_DECODE;
               end
            end
         end

         // ****************************************************************
         // DECODE
         // ****************************************************************
         S_DECODE: begin
            if (bus_stb && bus_ack) begin
               if (dec_illegal) begin
                  bus_stb <= 1'b0;
                  state   <= S_ERROR;

               // *** Stack Operations ***
               end else if (dec_is_stack) begin
                  if (dec_reg_src == `REG_A || dec_reg_src == `REG_P) begin
                     // PHA/PHP pre-launch stack write
                     pre_write({8'h01, reg_sp},
                               (dec_reg_src == `REG_A) ? reg_a : (reg_p | 8'h30));
                     state <= S_PUSH;
                  end else begin
                     // PLA/PLP pre-launch pull from SP+1
                     reg_sp <= reg_sp + 1'b1;
                     pre_read({8'h01, reg_sp + 1'b1});
                     state  <= S_PULL_READ;
                  end

               // *** BRK ***
               end else if (dec_is_brk) begin
                  // Skip padding byte, pre-launch push of PC+2 high byte
                  reg_pc          <= pc_plus_1;
                  is_software_int <= 1'b1;
                  pre_write({8'h01, reg_sp}, pc_plus_1[15:8]);
                  state           <= S_INT_PUSH_PCL;

               // *** RTS / RTI ***
               end else if (dec_is_return) begin
                  // Pre-launch first pull (P for RTI, PCL for RTS) from SP+1
                  reg_sp <= reg_sp + 1'b1;
                  pre_read({8'h01, reg_sp + 1'b1});
                  state  <= (opcode_reg == 8'h40) ? S_RET_P : S_RET_PCL;

               // *** Implied / Accumulator ***
               end else if (dec_addr_mode == `AM_IMP || dec_addr_mode == `AM_ACC) begin
                  write_result;
                  update_flags;
                  if (opcode_reg == 8'h18) reg_p[`FLAG_C] <= 1'b0;
                  if (opcode_reg == 8'h38) reg_p[`FLAG_C] <= 1'b1;
                  if (opcode_reg == 8'h58) reg_p[`FLAG_I] <= 1'b0;
                  if (opcode_reg == 8'h78) reg_p[`FLAG_I] <= 1'b1;
                  if (opcode_reg == 8'hB8) reg_p[`FLAG_V] <= 1'b0;
                  if (opcode_reg == 8'hD8) reg_p[`FLAG_D] <= 1'b0;
                  if (opcode_reg == 8'hF8) reg_p[`FLAG_D] <= 1'b1;
                  state <= S_FETCH;

               // *** Immediate ***
               end else if (dec_addr_mode == `AM_IMM) begin
                  write_result;
                  update_flags;
                  temp_data <= bus_rdata;
                  reg_pc    <= reg_pc + 1'b1;
                  bus_addr  <= reg_pc + 1'b1;
                  bus_stb   <= 1'b1;
                  bus_we    <= 1'b0;
                  state     <= S_FETCH;

               // *** Branch ***
               end else if (dec_is_branch) begin
                  temp_data <= bus_rdata;
                  reg_pc    <= reg_pc + 1'b1;
                  if (branch_taken)
                     reg_pc <= reg_pc + 1'b1 + {{8{bus_rdata[7]}}, bus_rdata};
                  // Pre-launch next fetch from PC
                  if (branch_taken)
                     bus_addr <= reg_pc + 1'b1 + {{8{bus_rdata[7]}}, bus_rdata};
                  else
                     bus_addr <= reg_pc + 1'b1;
                  bus_stb <= 1'b1;
                  bus_we  <= 1'b0;
                  state   <= S_FETCH;

               // *** Zero Page ***
               end else if (dec_addr_mode == `AM_ZP) begin
                  target_addr <= {8'h00, bus_rdata};
                  reg_pc      <= reg_pc + 1'b1;
                  if (dec_mem_read) begin
                     // Pre-launch ZP read
                     pre_read({8'h00, bus_rdata});
                     state <= S_EXEC;
                  end else begin
                     // ZP write: pre-launch write
                     pre_write({8'h00, bus_rdata}, store_data);
                     state <= S_MEM_WRITE;
                  end

               // *** Zero Page,X / Zero Page,Y ***
               end else if (dec_addr_mode == `AM_ZPX || dec_addr_mode == `AM_ZPY) begin
                  reg_pc <= reg_pc + 1'b1;
                  // Address calc: ZP wraps
                  if (dec_addr_mode == `AM_ZPX)
                     target_addr <= {8'h00, bus_rdata + reg_x};
                  else
                     target_addr <= {8'h00, bus_rdata + reg_y};
                  // Need 1 extra cycle for addr calc go through ADDR_CALC
                  temp_data <= bus_rdata;
                  bus_stb   <= 1'b0;
                  state     <= S_ADDR_CALC;

               // *** Absolute / Absolute,X / Absolute,Y / Indirect ***
               end else if (dec_addr_mode == `AM_ABS || dec_addr_mode == `AM_ABX ||
                            dec_addr_mode == `AM_ABY || dec_addr_mode == `AM_IND) begin
                  // Need second byte: save low byte, pre-launch high byte fetch
                  target_addr[7:0] <= bus_rdata;
                  reg_pc           <= reg_pc + 1'b1;
                  pre_read(reg_pc + 1'b1);
                  state <= S_FETCH_HI;

               // *** (Indirect,X) ***
               end else if (dec_addr_mode == `AM_IZX) begin
                  reg_pc   <= reg_pc + 1'b1;
                  // ZP pointer = (operand + X) & 0xFF
                  ptr_addr <= {8'h00, bus_rdata + reg_x};
                  bus_stb  <= 1'b0;
                  state    <= S_IND_LO;

               // *** (Indirect),Y ***
               end else if (dec_addr_mode == `AM_IZY) begin
                  reg_pc   <= reg_pc + 1'b1;
                  ptr_addr <= {8'h00, bus_rdata};
                  // Pre-launch read of ZP pointer low byte
                  pre_read({8'h00, bus_rdata});
                  state <= S_IND_LO;

               end else begin
                  bus_stb <= 1'b0;
                  state   <= S_ERROR;
               end
            end
         end

         // ****************************************************************
         // FETCH_HI
         // ****************************************************************
         S_FETCH_HI: begin
            if (bus_stb && bus_ack) begin
               target_addr[15:8] <= bus_rdata;
               reg_pc            <= reg_pc + 1'b1;

               if (dec_addr_mode == `AM_ABS) begin
                  if (dec_is_jump) begin
                     // JMP absolute: set PC, overlap fetch
                     pre_read({bus_rdata, target_addr[7:0]});
                     reg_pc <= {bus_rdata, target_addr[7:0]};
                     state  <= S_FETCH;
                  end else if (dec_is_jsr) begin
                     // JSR: save target, pre-launch push of return address
                     // high byte (PC still points at the last JSR byte)
                     target_addr <= {bus_rdata, target_addr[7:0]};
                     pre_write({8'h01, reg_sp}, reg_pc[15:8]);
                     state       <= S_JSR_PUSH_PCL;
                  end else if (dec_mem_read) begin
                     pre_read({bus_rdata, target_addr[7:0]});
                     state <= S_EXEC;
                  end else if (dec_mem_write) begin
                     pre_write({bus_rdata, target_addr[7:0]}, store_data);
                     target_addr <= {bus_rdata, target_addr[7:0]};
                     state       <= S_MEM_WRITE;
                  end else begin
                     bus_stb <= 1'b0;
                     state   <= S_ERROR;
                  end

               end else if (dec_addr_mode == `AM_IND) begin
                  // JMP indirect: pre-launch pointer low read
                  pre_read({bus_rdata, target_addr[7:0]});
                  ptr_addr <= {bus_rdata, target_addr[7:0]};
                  state    <= S_IND_LO;

               end else if (dec_addr_mode == `AM_ABX || dec_addr_mode == `AM_ABY) begin
                  // Need index calculation
                  temp_data <= bus_rdata;
                  bus_stb   <= 1'b0;
                  state     <= S_ADDR_CALC;
               end else begin
                  bus_stb <= 1'b0;
                  state   <= S_ERROR;
               end
            end
         end

         // ****************************************************************
         // ADDR_CALC
         // ****************************************************************
         S_ADDR_CALC: begin
            if (dec_addr_mode == `AM_ABX) begin
               target_addr <= {temp_data, target_addr[7:0]} + {8'h00, reg_x};
            end else if (dec_addr_mode == `AM_ABY) begin
               target_addr <= {temp_data, target_addr[7:0]} + {8'h00, reg_y};
            end

            if (dec_mem_read) begin
               state <= S_EXEC;
               if (dec_addr_mode == `AM_ZPX)
                  pre_read({8'h00, temp_data + reg_x});
               else if (dec_addr_mode == `AM_ZPY)
                  pre_read({8'h00, temp_data + reg_y});
               else if (dec_addr_mode == `AM_ABX)
                  pre_read({temp_data, target_addr[7:0]} + {8'h00, reg_x});
               else if (dec_addr_mode == `AM_ABY)
                  pre_read({temp_data, target_addr[7:0]} + {8'h00, reg_y});
               else if (dec_addr_mode == `AM_IZY)
                  pre_read(target_addr + {8'h00, reg_y});
            end else if (dec_mem_write) begin
               state <= S_MEM_WRITE;
               if (dec_addr_mode == `AM_ZPX)
                  pre_write({8'h00, temp_data + reg_x}, store_data);
               else if (dec_addr_mode == `AM_ZPY)
                  pre_write({8'h00, temp_data + reg_y}, store_data);
               else if (dec_addr_mode == `AM_ABX)
                  pre_write({temp_data, target_addr[7:0]} + {8'h00, reg_x}, store_data);
               else if (dec_addr_mode == `AM_ABY)
                  pre_write({temp_data, target_addr[7:0]} + {8'h00, reg_y}, store_data);
               else if (dec_addr_mode == `AM_IZY)
                  pre_write(target_addr + {8'h00, reg_y}, store_data);
               // Update target_addr for IZY
               if (dec_addr_mode == `AM_IZY)
                  target_addr <= target_addr + {8'h00, reg_y};
            end
         end

         // ****************************************************************
         // IND_LO: Read indirect pointer low byte
         // ****************************************************************
         S_IND_LO: begin
            if (bus_stb && bus_ack) begin
               target_addr[7:0] <= bus_rdata;
               // Pre-launch high byte read
               if (dec_addr_mode == `AM_IND)
                  pre_read(ptr_addr + 16'h0001); // 65C02 behavior: full 16-bit increment
               else
                  pre_read({ptr_addr[15:8], ptr_addr[7:0] + 8'h01}); // ZP wrap for IZX/IZY
               state <= S_IND_HI;
            end else begin
               // IZX enters without pre-launch
               pre_read(ptr_addr);
            end
         end

         // ****************************************************************
         // IND_HI: Read indirect pointer high byte
         // ****************************************************************
         S_IND_HI: begin
            if (bus_stb && bus_ack) begin
               target_addr[15:8] <= bus_rdata;

               if (dec_addr_mode == `AM_IND) begin
                  // JMP indirect: overlap fetch
                  pre_read({bus_rdata, target_addr[7:0]});
                  reg_pc <= {bus_rdata, target_addr[7:0]};
                  state  <= S_FETCH;
               end else if (dec_addr_mode == `AM_IZX) begin
                  // Pre-launch final read from resolved address
                  if (dec_mem_read) begin
                     pre_read({bus_rdata, target_addr[7:0]});
                     state <= S_EXEC;
                  end else begin
                     pre_write({bus_rdata, target_addr[7:0]}, store_data);
                     target_addr <= {bus_rdata, target_addr[7:0]};
                     state       <= S_MEM_WRITE;
                  end
               end else if (dec_addr_mode == `AM_IZY) begin
                  // Need to add Y go through ADDR_CALC
                  target_addr[15:8] <= bus_rdata;
                  bus_stb           <= 1'b0;
                  state             <= S_ADDR_CALC;
               end
            end
         end

         // ****************************************************************
         // EXEC
         // ****************************************************************
         S_EXEC: begin
            if (bus_stb && bus_ack) begin
               temp_data <= bus_rdata;
               write_result;
               update_flags;
               if (dec_mem_read && dec_mem_write) begin
                  pre_write(target_addr, alu_out);
                  state <= S_MEM_WRITE;
               end else begin
                  pre_fetch_next;
                  state <= S_FETCH;
               end
            end
         end

         // ****************************************************************
         // MEM_WRITE
         // ****************************************************************
         S_MEM_WRITE: begin
            if (bus_stb && bus_ack) begin
               // Write done. Overlap: pre-launch next fetch.
               pre_fetch_next;
               state <= S_FETCH;
            end
         end

         // ****************************************************************
         // Stack Operations (PHA/PHP/PLA/PLP)
         // ****************************************************************
         S_PUSH: begin
            if (bus_stb && bus_ack) begin
               pre_fetch_next;
               reg_sp <= reg_sp - 1'b1;
               state  <= S_FETCH;
            end
         end

         S_PULL_READ: begin
            if (bus_stb && bus_ack) begin
               temp_data <= bus_rdata;
               write_result;
               update_flags;
               pre_fetch_next;
               state <= S_FETCH;
            end
         end

         // ****************************************************************
         // JSR: Push PC-1 (return addr), jump to target
         // Flow: FETCH_HI (PCH push launched) -> PUSH_PCL -> JUMP
         // ****************************************************************
         S_JSR_PUSH_PCL: begin
            if (bus_stb && bus_ack) begin
               // Pre-launch write of PCL to stack
               pre_write({8'h01, reg_sp - 1'b1}, jsr_ret_pcl);
               reg_sp <= reg_sp - 1'b1;
               state  <= S_JSR_JUMP;
            end
         end

         S_JSR_JUMP: begin
            if (bus_stb && bus_ack) begin
               reg_sp <= reg_sp - 1'b1;
               // Jump to target and overlap fetch
               reg_pc <= target_addr;
               pre_read(target_addr);
               state  <= S_FETCH;
            end
         end

         // ****************************************************************
         // RTS / RTI: Pull [P], PCL, PCH
         // Flow: DECODE (first pull launched) -> [RET_P, RTI only] -> RET_PCL
         //       -> RET_PCH -> FETCH
         // Each RET_* state receives the named byte and pre-launches the next.
         // ****************************************************************
         S_RET_P: begin
            if (bus_stb && bus_ack) begin
               // Restore P (bit 5 always 1, B-flag preserved from CPU)
               reg_p  <= {bus_rdata[7:6], 1'b1, reg_p[4], bus_rdata[3:0]};
               reg_sp <= reg_sp + 1'b1;
               pre_read({8'h01, reg_sp + 1'b1});
               state  <= S_RET_PCL;
            end
         end

         S_RET_PCL: begin
            if (bus_stb && bus_ack) begin
               temp_data <= bus_rdata;
               reg_sp    <= reg_sp + 1'b1;
               pre_read({8'h01, reg_sp + 1'b1});
               state     <= S_RET_PCH;
            end
         end

         S_RET_PCH: begin
            if (bus_stb && bus_ack) begin
               if (opcode_reg == 8'h40) begin
                  // RTI: resume at the pulled address
                  reg_pc <= {bus_rdata, temp_data};
                  pre_read({bus_rdata, temp_data});
               end else begin
                  // RTS: pulled address is the last JSR byte, resume after it
                  reg_pc <= {bus_rdata, temp_data} + 16'h0001;
                  pre_read({bus_rdata, temp_data} + 16'h0001);
               end
               state <= S_FETCH;
            end
         end

         // ****************************************************************
         // Interrupt Sequence (NMI, IRQ, BRK)
         // Flow: FETCH/DECODE (PCH push launched) -> PUSH_PCL -> PUSH_P
         //       -> VEC_LO -> VEC_HI -> FETCH
         // ****************************************************************
         S_INT_PUSH_PCL: begin
            if (bus_stb && bus_ack) begin
               pre_write({8'h01, reg_sp - 1'b1}, reg_pc[7:0]);
               reg_sp <= reg_sp - 1'b1;
               state  <= S_INT_PUSH_P;
            end
         end

         S_INT_PUSH_P: begin
            if (bus_stb && bus_ack) begin
               reg_sp <= reg_sp - 1'b1;
               pre_write({8'h01, reg_sp - 1'b1},
                         {reg_p[7:6], 1'b1, is_software_int, reg_p[3:0]});
               state  <= S_INT_VEC_LO;
            end
         end

         S_INT_VEC_LO: begin
            if (bus_stb && bus_ack) begin
               reg_sp         <= reg_sp - 1'b1;
               reg_p[`FLAG_I] <= 1'b1;
               // Latch vector choice; an NMI arriving later stays pending
               int_is_nmi     <= nmi_pending;
               pre_read(nmi_pending ? 16'hFFFA : 16'hFFFE);
               state <= S_INT_VEC_HI;
            end
         end

         S_INT_VEC_HI: begin
            if (bus_stb && bus_ack) begin
               if (bus_addr[0] == 1'b0) begin
                  // Read vector low byte
                  temp_data <= bus_rdata;
                  pre_read(int_is_nmi ? 16'hFFFB : 16'hFFFF);
               end else begin
                  // Read vector high byte (nmi_ack clears a taken NMI)
                  reg_pc  <= {bus_rdata, temp_data};
                  pre_read({bus_rdata, temp_data});
                  state   <= S_FETCH;
               end
            end
         end

         S_ERROR: begin
            // Halt
         end

         default: state <= S_RESET_0;
         endcase
      end
   end

   // ****************************************************************
   // ALU Setup
   // ****************************************************************
   always @(*) begin
      // Determine ALU Source A from decoder signal
      case (dec_alu_src_a)
         `REG_A:   alu_a = reg_a;
         `REG_X:   alu_a = reg_x;
         `REG_Y:   alu_a = reg_y;
         default:  alu_a = reg_a;
      endcase

      alu_op       = dec_alu_op;
      alu_carry_in = reg_p[`FLAG_C];

      // Determine ALU Source B with bus bypass for immediate/memory reads
      alu_b = 8'h00;
      case (dec_reg_src)
         `REG_A:    alu_b = reg_a;
         `REG_X:    alu_b = reg_x;
         `REG_Y:    alu_b = reg_y;
         `REG_SP:   alu_b = reg_sp;
         `REG_P:    alu_b = reg_p;
         `REG_MEM:  begin
            // Bus bypass: in states where data is on bus_rdata, use it directly
            if ((state == S_DECODE && dec_addr_mode == `AM_IMM) ||
               (state == S_EXEC) ||
               (state == S_PULL_READ))
               alu_b = bus_rdata;
            else
               alu_b = temp_data;
         end
         default: alu_b = 8'h00;
      endcase
   end

endmodule
