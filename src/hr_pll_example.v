/* ****************************************************************************
-- (C) Copyright 2018 Kevin Hubbard - All rights reserved.
-- Source file: hr_pll_example.v     
-- Date:        July 2018     
-- Author:      khubbard
-- Description: Example of interfacing to hyper_xface_pll.v
-- Language:    Verilog-2001
-- Simulation:  Xilinx-Vivado   
-- Synthesis:   Xilinx-Vivado
-- License:     This project is licensed with the CERN Open Hardware Licence
--              v1.2.  You may redistribute and modify this project under the
--              terms of the CERN OHL v.1.2. (http://ohwr.org/cernohl).
--              This project is distributed WITHOUT ANY EXPRESS OR IMPLIED
--              WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
--              AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN OHL
--              v.1.2 for applicable Conditions.
--
-- Write Cycle Single and Burst:
-- In:
--   clk           _/ \_/ \_/ \_/ \_/ \_/ \_/ \
--   lb_wr         _____/  \________/      \___
--   lb_addr[31:0] -----<  >--------<  ><  >---
--   lb_wr_d[31:0] -----<  >--------<  ><  >---
--
-- Read Cycle Single Only Allowed. Bus is unavailable until cycle completed.
-- In:
--   clk           _/ \_/ \_/ \_/ \_/ \_/ \_/ \
--   lb_rd         _____/  \________/      \___
--   lb_addr[31:0] -----<  >--------<  >-------
-- Out:
--   lb_rd_d[31:0] -----------------<  >-------
--   lb_rd_rdy     _________________/  \_______
--                          |------| Variable Latency ( 1024 limit typically )
--
--
-- Revision History:
-- Ver#  When      Who      What
-- ----  --------  -------- ---------------------------------------------------
-- 0.1   07.01.18  khubbard Creation
-- ***************************************************************************/
`timescale 1 ns/ 100 ps
`default_nettype none // Strictly enforce all nets to be declared
                                                                                
module hr_pll_example
(
  input  wire        simulation_en,
  input  wire        auto_cfg_en,
  input  wire        reset,
  input  wire        clk,
  input  wire        clk_90p,
  input  wire        lb_wr,
  input  wire        lb_rd,
  input  wire [31:0] lb_addr,
  input  wire [31:0] lb_wr_d,
  output reg  [31:0] lb_rd_d,
  output reg         lb_rd_rdy,
  output wire [31:0] sump2_events,

  input  wire [7:0]  dram_dq_in,
  output wire [7:0]  dram_dq_out,
  output wire        dram_dq_oe_l,

  input  wire        dram_rwds_in,
  output wire        dram_rwds_out,
  output wire        dram_rwds_oe_l,

  output wire        dram_ck,
  output wire        dram_rst_l,
  output wire        dram_cs_l,

  // XXX added for debug:
  output wire        hyperram_busy,
  input  wire        busy_stuck
);// module top

  assign hyperram_busy = hr_busy;

  reg           hr_rd_req;
  reg           hr_wr_req;
  reg           hr_mem_or_reg;
  reg  [31:0]   hr_addr;
  reg  [5:0]    hr_rd_num_dwords;
  reg  [31:0]   hr_wr_d;
  wire [31:0]   hr_rd_d;
  wire          hr_rd_rdy;
  wire          hr_busy;
  reg           hr_busy_p1;
  wire          hr_burst_wr_rdy;
  reg  [31:0]   lb_0010_reg;
  reg  [31:0]   lb_0014_reg;
  reg  [31:0]   lb_0018_reg;
  reg  [31:0]   lb_001c_reg;
  reg  [31:0]   hr_cfg_dword;
  reg  [14:0]   rst_cnt;
  reg           rst_done;
  reg           rst_done_p1;
  reg           cfg_busy;
  reg           cfg_now;
  wire [31:0]   hr_dflt_timing;
  wire [7:0]    cycle_len;


//-----------------------------------------------------------------------------
// This 32bit value is determined by both the HyperRAM clock rate (83-166 MHz)
// and prefence for variable 1x/2x latency, or fixed 2x always latency.
// See Section-3 of hyper_xface.pll doc for the 8 different valid 32bit values.
//-----------------------------------------------------------------------------
  assign hr_dflt_timing = 32'h8ff40000; // 100 MHz Variable Latency


//-----------------------------------------------------------------------------
// HyperRAM requires a 150uS delay from power on prior to configuration.  
// Delay 2^15 clocks from reset then issue the config cycle pulse cfg_now.
// This may optionally be used to automatically configure the HyperRAM speed.
//-----------------------------------------------------------------------------
always @( posedge clk )
begin
  rst_done_p1 <= rst_done;
  cfg_now     <= rst_done & ~rst_done_p1;// Rising Edge Detect

  if ( rst_cnt != 15'h7FFF ) begin
    rst_cnt  <= rst_cnt[14:0] + 1;
    rst_done <= 0;
    cfg_busy <= 1;
  end else begin
    rst_done <= 1;
    cfg_busy <= 0;
  end

  if ( reset == 1 ) begin
    rst_cnt  <= 15'd0;
    rst_done <= 0;
    cfg_busy <= 1;
  end
  if ( auto_cfg_en == 0 ) begin
    cfg_now <= 0;
  end
end // always


//-----------------------------------------------------------------------------
// Instead of waiting 150uS from Power On to configure the HyperRAM, wait
// until 1st LB cycle from Reset then issue the cfg.
//   Default 6 Clock 166 MHz Latency, latency1x=0x12, latency2x=0x16
//     CfgReg0 write(0x00000800, 0x8f1f0000);
//   Configd 3 Clock  83 MHz Latency, latency1x=0x04, latency2x=0x0a
//     CfgReg0 write(0x00000800, 0x8fe40000);
//
// The FIFO with Deep Sump writes gets popped whenever HyperRAM is available.
// Deep Sump read requests are multi cycle. They come in on the b_clk domain
//
// 0x0010 : Address
// 0x0014 : Data Buffer : DWORD0
// 0x0018 : Data Buffer : DWORD1
// 0x001C : Control   
//            1 : Write Single DWORD
//            2 : Read  Single DWORD XXX NOTE THIS DOESN'T WORK!
//            3 : Write Burst two DWORDs
//            4 : Read  Burst two DWORDs
//            5 : Write Configuration    
//            6 : Read  Configuration - Not Implemented
// 
// Cypress Values:
// D(23:20) = Initial Latency
//            0xF = 100 MHz 4-Clock
//            0xE =  83 MHz 3-Clock
//            0x1 = 166 MHz 6-Clock (Def)
//            0x0 = 133 MHz 5-Clock
// D(19)    = 0=Variable Latency, 1=Fixed 2x Latency (Def)
// D(18)    = Hybrid Burst Enable 0=Hybrid, 1=Legacy (Def)
// D(17:16) = Burst Length 00=128 Bytes, 11=32 Bytes (Def)
//-----------------------------------------------------------------------------
always @( posedge clk )
begin
  lb_rd_d          <= 32'd0;
  lb_rd_rdy        <= 0;
  hr_busy_p1       <= hr_busy;
  hr_rd_req        <= 0;
  hr_wr_req        <= 0;
  hr_mem_or_reg    <= 0;

  if ( lb_wr == 1 ) begin
    if ( lb_addr[15:0] == 16'h0010 ) begin
      lb_0010_reg <= lb_wr_d[31:0];
    end
    if ( lb_addr[15:0] == 16'h0014 ) begin
      lb_0014_reg <= lb_wr_d[31:0];
    end
    if ( lb_addr[15:0] == 16'h0018 ) begin
      lb_0018_reg <= lb_wr_d[31:0];
    end
    if ( lb_addr[15:0] == 16'h001c ) begin
      lb_001c_reg <= lb_wr_d[31:0];
    end
  end 

  if ( lb_rd == 1 ) begin
    if ( lb_addr[15:0] == 16'h0010 ) begin
      lb_rd_d   <= lb_0010_reg[31:0];
      lb_rd_rdy <= 1;
    end 
    if ( lb_addr[15:0] == 16'h0014 ) begin
      lb_rd_d   <= lb_0014_reg[31:0];
      lb_rd_rdy <= 1;
    end 
    if ( lb_addr[15:0] == 16'h0018 ) begin
      lb_rd_d   <= lb_0018_reg[31:0];
      lb_rd_rdy <= 1;
    end 
    if ( lb_addr[15:0] == 16'h001c ) begin
//    lb_rd_d   <= lb_001c_reg[31:0];
      lb_rd_d   <= { 24'd0, cycle_len[7:0] };
      lb_rd_rdy <= 1;
    end 
  end 

  // Single DWORD Write
  if ( lb_001c_reg[2:0] == 3'd1 && hr_busy == 0 ) begin
    hr_addr       <= lb_0010_reg[31:0];
    hr_wr_d       <= lb_0014_reg[31:0]; 
    hr_wr_req     <= 1;
    hr_mem_or_reg <= 0;// DRAM access
    lb_001c_reg   <= 32'd0; // Self Clearing
  end 


  // Single DWORD Read
  if ( lb_001c_reg[2:0] == 3'd2 && hr_busy == 0 ) begin
    hr_addr          <= lb_0010_reg[31:0];
    hr_rd_req        <= 1;
    hr_mem_or_reg    <= 0;// DRAM access
    hr_rd_num_dwords <= 6'd1;
    lb_001c_reg      <= 32'd0; // Self Clearing
  end 


  // Burst Write of 2 DWORDs. 
  // 2nd DWORD must launch as soon hr_burst_wr_rdy asserts
  if ( lb_001c_reg[2:0] == 3'd3 ) begin
    if ( hr_busy == 0 ) begin
      hr_addr       <= lb_0010_reg[31:0];
      hr_wr_d       <= lb_0014_reg[31:0]; 
      hr_wr_req     <= 1;
      hr_mem_or_reg <= 0;// DRAM access
    end else if ( hr_burst_wr_rdy == 1 ) begin 
      hr_wr_d       <= lb_0018_reg[31:0]; 
      hr_wr_req     <= 1;
      hr_mem_or_reg <= 0;// DRAM access
      lb_001c_reg   <= 32'd0; // Self Clearing after 2nd DWORD
    end
  end


  // Burst Read of 2 DWORDs
  if ( lb_001c_reg[2:0] == 3'd4 ) begin
    if ( hr_busy == 0 && hr_busy_p1 == 0 ) begin
      hr_addr          <= lb_0010_reg[31:0];
      hr_rd_req        <= 1;
      hr_mem_or_reg    <= 0;// DRAM access
      hr_rd_num_dwords <= 6'd2;
    end else if ( hr_busy == 1 ) begin
      if ( hr_rd_rdy == 1 ) begin
        lb_0018_reg <= hr_rd_d[31:0];
        lb_0014_reg <= lb_0018_reg[31:0];
      end
    end else if ( hr_busy == 0 && hr_busy_p1 == 1 ) begin
      lb_001c_reg   <= 32'd0; // Self Clearing after 2nd DWORD
    end
  end

  // Make sure pulses are only one clock wide for bursts
  if ( hr_wr_req == 1 ) begin
    hr_wr_req <= 0;
  end
  if ( hr_rd_req == 1 ) begin
    hr_rd_req <= 0;
  end


  // Configuration Write : Either via the 0x1C register of the 150uS Timer
  if ( ( cfg_now == 1 || lb_001c_reg[2:0] == 3'd5 ) && hr_busy == 0 ) begin
    hr_addr       <= 32'h00000800;
    hr_wr_d       <= lb_0014_reg[31:0]; 
    hr_cfg_dword  <= lb_0014_reg[31:0]; 
    hr_mem_or_reg <= 1;// Config Reg Write instead of DRAM Write
    hr_wr_req     <= 1;
    lb_001c_reg   <= 32'd0; // Self Clearing
  end 

  if ( lb_001c_reg[2:0] == 3'd6 && hr_busy == 0 ) begin
    lb_rd_d       <= hr_cfg_dword[31:0];
    lb_rd_rdy     <= 1;
    lb_001c_reg   <= 32'd0; // Self Clearing
  end 


  if ( reset == 1 ) begin
    lb_0010_reg  <= 32'd0;
    lb_0018_reg  <= 32'd0;
    lb_001c_reg  <= 32'd0;
    lb_0014_reg  <= hr_dflt_timing[31:0];
    hr_cfg_dword <= hr_dflt_timing[31:0];
  end

end // always


//-----------------------------------------------------------------------------
// Bridge to a HyperRAM
//-----------------------------------------------------------------------------
hyper_xface_pll u_hyper_xface_pll
(
  .simulation_en     ( simulation_en         ),
  .reset             ( reset                 ),
  .clk               ( clk                   ),
  .clk_90p           ( clk_90p               ),
  .rd_req            ( hr_rd_req             ),
  .wr_req            ( hr_wr_req             ),
  .mem_or_reg        ( hr_mem_or_reg         ),
  .addr              ( hr_addr[31:0]         ),
  .rd_num_dwords     ( hr_rd_num_dwords[5:0] ),
  .wr_d              ( hr_wr_d[31:0]         ),
  .rd_d              ( hr_rd_d[31:0]         ),
  .rd_rdy            ( hr_rd_rdy             ),
  .busy              ( hr_busy               ),
  .burst_wr_rdy      ( hr_burst_wr_rdy       ),
  .lat_2x            (                       ),
  .sump_dbg          ( sump2_events[31:0]    ),
  .cycle_len         ( cycle_len[7:0]        ),

  .dram_dq_in        ( dram_dq_in[7:0]       ),
  .dram_dq_out       ( dram_dq_out[7:0]      ),
  .dram_dq_oe_l      ( dram_dq_oe_l          ),
  .dram_rwds_in      ( dram_rwds_in          ),
  .dram_rwds_out     ( dram_rwds_out         ),
  .dram_rwds_oe_l    ( dram_rwds_oe_l        ),
  .dram_ck           ( dram_ck               ),
  .dram_rst_l        ( dram_rst_l            ),
  .dram_cs_l         ( dram_cs_l             ),

  .busy_stuck        ( busy_stuck            )
);// module hyper_xface_pll


`ifdef ILA_HYPERRAM
   ila_hyperram U_ila_hyperram (
       .clk         (clk                ),
       .probe0      (hr_wr_req          ),
       .probe1      (hr_wr_d            ),      // 31:0
       .probe2      (hr_mem_or_reg      ),
       .probe3      (hr_rd_req          ),
       .probe4      (hr_rd_d            ),      // 31:0
       .probe5      (lb_0010_reg        ),      // 31:0
       .probe6      (lb_0014_reg        ),      // 31:0
       .probe7      (lb_0018_reg        ),      // 31:0
       .probe8      (lb_001c_reg        ),      // 31:0
       .probe9      (hr_busy            ),
       .probe10     (hr_busy_p1         ),
       .probe11     (hr_rd_rdy          ),
       .probe12     (hr_burst_wr_rdy    ),
       .probe13     (lb_wr              ),
       .probe14     (lb_addr            ),      // 31:0
       .probe15     (lb_wr_d            )       // 31:0
   );                            
`endif


endmodule // hr_pll_example.v
`default_nettype wire // enable Verilog default for any 3rd party IP needing it
