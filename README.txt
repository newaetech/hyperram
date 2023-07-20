This is the open-source FPGA HyperRAM interface for Xilinx 7-Series with PLL phase shift.
 ./src/     : RTL Source Directory
 ./sim/     : Xilinx Vivado Simulation directory


About:
 HyperRAM is a DRAM technology that uses a single DDR bidirectional byte bus for both
 Command, Address and Data transfers. The advantages HyperRAM has over standard DRAM
 are many:
   1) Low Pin Count - only 12 FPGA pins needed.
   2) Simple I/O technlogy - either LVCMOS 3.3V or 1.8V.
   3) Built in refresh-controller.
 Timing is tricky however. Issues with HyperRAM:
   1) Required a clock that is 90o phase shifted from all other signals.
   2) HyperRAM must be programmed for a certain latency per clock and
      the interface core must know what that latency is.

 The hyper_xface_pll.v module uses a 32bit DWORD bus. On the fabric side, once
 the HyperRAM is going, the FPGA fabric needs to source (Writes) or accept (Reads)
 a new DWORD every other clock cycle to match the byte lane DDR physical interface.


Timing for the 8 different clock / latency settings for 2 DWORD Writes and Reads:
                     WR /RD                       WR/RD
#w 14 8fe40000    #  8 / 14   83 MHz 1x Latency = 96/169 ns
#w 14 8ff40000    #  9 / 15  100 MHz 1x Latency = 90/150 ns
#w 14 8f040000    # 10 / 16  133 MHz 1x Latency = 75/120 ns
#w 14 8f140000    # 11 / 17  166 MHz 1x Latency = 66/102 ns
#w 14 8fec0000    # 11 / 17   83 MHz 2x Latency   
#w 14 8ffc0000    # 13 / 19  100 MHz 2x Latency
#w 14 8f0c0000    # 15 / 21  133 MHz 2x Latency
#w 14 8f1c0000    # 17 / 23  166 MHz 2x Latency


Tested up to 91 MHz at 16mA Fast without failures. Started dropping bits at 92 MHz.
2018.08.09