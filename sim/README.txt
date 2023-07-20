README.txt  : This file
compile.sh  : Compile the Verilog RTL and list any Syntax Errors.
simulate.sh : Simulate the compiled design and generate dump.vcd VCD file.
top.prj     : List of Verilog RTL files to compile.
vsim.opt    : List of libraries ( Xilinx primitives, etc ) to use for sims.
./do_files/ : Directory with TCL files do.tcl, wave.tcl, force*.tcl
make_gtkwave_gtkw.py : Optional Python script that reads in simulation info
                       and creates a nice *.gtkw file for organizing signals.
