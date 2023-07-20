###############################################################################
# Xilinx Vivado simulation force file for hyper_xface_pll.v 2018.08.08
# This 
add_force reset         1 
add_force simulation_en 1
add_force clk           {0 0ns} {1 5ns} -repeat_every 10ns
add_force clk_90p       {1 0ns} {0 2ns} {1 7ns} -repeat_every 10ns
add_force rd_req        0
add_force wr_req        0
add_force mem_or_reg    0
add_force rd_num_dwords 00 -radix hex
add_force addr          00000000 -radix hex
add_force wr_d          00000000 -radix hex
add_force dram_dq_in    00 -radix hex
add_force dram_rwds_in  0               
run 100ns
add_force reset    0
run 25ns
############################################################
# Set the Configuration Register for 83 MHz Fixed 2x access
add_force wr_req        1
add_force mem_or_reg    1
add_force addr          00000800 -radix hex
add_force wr_d          8fec0000 -radix hex
run 10ns
add_force wr_req        0
add_force mem_or_reg    0
add_force addr          00000000 -radix hex
add_force wr_d          00000000 -radix hex
run 100ns
############################################################
# Burst Write 2 DWORDs
add_force wr_req        1
add_force addr          00000000 -radix hex
add_force wr_d          11223344 -radix hex
run 10ns
add_force wr_req        0
add_force addr          00000000 -radix hex
add_force wr_d          00000000 -radix hex
run 100ns
add_force wr_req        1
add_force addr          00000000 -radix hex
add_force wr_d          55667788 -radix hex
run 10ns
add_force wr_req        0
add_force addr          00000000 -radix hex
add_force wr_d          00000000 -radix hex
run 100ns
############################################################
# Read the 2 DWORDs back
add_force rd_req        1
add_force addr          00000000 -radix hex
add_force rd_num_dwords 02 -radix hex
run 10ns
add_force rd_req        0
add_force addr          00000000 -radix hex
add_force rd_num_dwords 00 -radix hex
run 200ns
############################################################
