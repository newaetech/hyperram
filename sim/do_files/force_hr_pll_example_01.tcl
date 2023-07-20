###############################################################################
# Xilinx Vivado simulation force file for hr_pll_example.v 2018.08.10
# This 
add_force reset         1 
add_force simulation_en 1
add_force auto_cfg_en   0
add_force clk           {0 0ns} {1 5ns} -repeat_every 10ns
add_force clk_90p       {1 0ns} {0 2ns} {1 7ns} -repeat_every 10ns

add_force lb_wr         0
add_force lb_rd         0
add_force lb_addr       00000000 -radix hex
add_force lb_wr_d       00000000 -radix hex
add_force dram_dq_in    00 -radix hex
add_force dram_rwds_in  0               
run 100ns
add_force reset    0
run 25ns
############################################################
#  0x0010 : Address
#  0x0014 : Data Buffer : DWORD0
#  0x0018 : Data Buffer : DWORD1
#  0x001C : Control
#             1 : Write Single DWORD
#             2 : Read  Single DWORD
#             3 : Write Burst two DWORDs
#             4 : Read  Burst two DWORDs
#             5 : Write Configuration
#             6 : Read  Configuration - Not Implemented
############################################################
# Set the Configuration Register for 83 MHz Fixed 2x access
add_force lb_wr         1
add_force lb_addr       00000014 -radix hex
add_force lb_wr_d       8fec0000 -radix hex
run 10ns
# Command to Write Configuration 
add_force lb_wr         1
add_force lb_addr       0000001c -radix hex
add_force lb_wr_d       00000005 -radix hex
run 10ns
# Wait
add_force lb_wr         0
add_force lb_addr       00000000 -radix hex
add_force lb_wr_d       00000000 -radix hex
run 200ns
############################################################
# Burst Write 2 DWORDs
# Set the DRAM Address
add_force lb_wr         1
add_force lb_addr       00000010 -radix hex
add_force lb_wr_d       00000000 -radix hex
run 10ns
# 1st DWORD of Data
add_force lb_wr         1
add_force lb_addr       00000014 -radix hex
add_force lb_wr_d       11223344 -radix hex
run 10ns
# 2nd DWORD of Data
add_force lb_wr         1
add_force lb_addr       00000018 -radix hex
add_force lb_wr_d       55667788 -radix hex
run 10ns
# Command to Write 2 DWORDs ( Burst )
add_force lb_wr         1
add_force lb_addr       0000001c -radix hex
add_force lb_wr_d       00000003 -radix hex
run 10ns
# Wait
add_force lb_wr         0
add_force lb_addr       00000000 -radix hex
add_force lb_wr_d       00000000 -radix hex
run 200ns
############################################################
# Read the 2 DWORDs back
# Command to Read 2 DWORDs ( Burst )
add_force lb_wr         1
add_force lb_addr       0000001c -radix hex
add_force lb_wr_d       00000004 -radix hex
run 10ns
# Wait
add_force lb_wr         0
add_force lb_addr       00000000 -radix hex
add_force lb_wr_d       00000000 -radix hex
run 200ns
############################################################
# Read the captured 2 DWORDs from Local Bus registers
# Command to Read 2 DWORDs ( Burst )
add_force lb_rd         1
add_force lb_addr       00000014 -radix hex
run 10ns
add_force lb_rd         0
add_force lb_addr       00000000 -radix hex
run 40ns
add_force lb_rd         1
add_force lb_addr       00000018 -radix hex
run 10ns
add_force lb_rd         0
add_force lb_addr       00000000 -radix hex
run 40ns
