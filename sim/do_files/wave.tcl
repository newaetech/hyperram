# List which nets are added to VCD file
# Example of VCDing specific nets
#  log_vcd {fifo_1024x36/clk_wr}
#  log_vcd {/clk_wr}
# VCD everything
log_vcd [get_objects -r * ]
