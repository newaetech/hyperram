#xelab hyper_xface_pll glbl -prj top.prj -s snapshot -debug typical -f vsim.opt
 xelab hr_pll_example  glbl -prj top.prj -s snapshot -debug typical -f vsim.opt
xsim snapshot -tclbatch do_files/do.tcl
cp dump.vcd ~/xfer
