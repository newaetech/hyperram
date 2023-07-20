#!/usr/bin/python
###############################################################################
# Copyright (c) 2018 Kevin M. Hubbard
# License:
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Description:
# Automatically build a *.gtkw file for GTKwave from a top level Verilog file. 
# Signals will be sorted into 3 groups for INs, OUTs and Internals.
#
# arg[1] : Simulation script ( like simulate.sh ) for parsing info from.
# arg[2] : GTKwave width  ( 1900 for example )
# arg[3] : GTKwave height (  900 for example )
# arg[4] : Optional "sav" instead of default *.gtkw for file extension
#
# Input Files:
#   [simulate.sh]
#     xelab  comp_foo glbl -prj top.prj
#
#   [top.prj]
#     verilog work "../comp_foo.v"
#
#   [comp_foo.v]
#     module comp_foo
#     (
#      input  wire       reset,
#      output wire [7:0] q0,
#     );
#     reg  [2:0]   rst_cnt;
#     ...
#     always @ (posedge clk_pop or posedge reset ) begin : proc_flops
# Output File:
#  [comp_foo.gtkw]
#    [*]
#    [size] 1900 900
#    -Inputs
#    comp_foo.reset
#    -Outputs
#    comp_foo.q0[7:0]
###############################################################################
import sys;
import os;

def main():
  args = sys.argv + [None]*5; # args[0] is this scripts name
  file_compile_sh = args[1]; # ie compile.sh
  win_width       = int( args[2], 10 ); # ie 1900
  win_height      = int( args[3], 10 ); # ie  900

  file_ext = "gtkw";
  if ( args[4] == "sav" ):
    file_ext = "sav";

  # Step-1 : Find the line "xelab  io_4to8_in_fifo glbl -prj top.prj"
  compile_sh_list = file2list( file_compile_sh ); # ie compile.sh
  xelab_parms = None;
  for each_line in compile_sh_list:
    words = " ".join(each_line.split()).split(' ') + [None] * 4;
    if ( words[0] == "xelab" ):
      xelab_parms = each_line;
  if ( xelab_parms == None ):
    print("ERROR parsing %s. Unable to find xelab" % file_compile_sh );
    sys.exit();

  # Step-2 : Find "comp_foo" and "-prj top.prj"
  words = " ".join(xelab_parms.split()).split(' ') + [None] * 4;
  module_name = words[1];
  file_top_prj = None;
  for ( i, each_word ) in enumerate( words ):
    if ( each_word == "-prj" ):
      file_top_prj = words[i+1];
  if ( file_top_prj == None ):
    print("ERROR parsing %s. Unable to find -prj" % file_compile_sh );
    sys.exit();

    
  # Step-3 : Open up "top.prj" and find pointer to "comp_foo.v"
  top_prj_list = file2list( file_top_prj ); # ie compile.sh
  file_module = None;
  for each_line in top_prj_list:
    words = " ".join(each_line.split()).split(' ') + [None] * 4;
    if ( words[0] == "verilog" ):
      if ( module_name + ".v" in words[2] ):
        file_module = words[2].replace('"', '');
  if ( file_module == None ):
    print("ERROR parsing %s. Unable to find %s" % (file_top_prj,module_name));
    sys.exit();

  # Step-4 : Parse a Verilog File and find al the ports and signal names
  ( in_list, out_list, int_list ) = parse_verilog( file_module ); 

  gtkw_list=make_gtkw(module_name,in_list,out_list,int_list,
                      win_width,win_height);
  file_gtkw = module_name + "." + file_ext;
  list2file( file_gtkw, gtkw_list );
  import shutil;
  shutil.copy( file_gtkw, "dump." + file_ext );
  sys.exit();


def file2list( file_name ):
  file_in  = open( file_name, 'r' );
  file_list = file_in.readlines();
  file_in.close();
  file_list = [ each.strip('\n') for each in file_list ];# list comprehension
  return file_list;


def list2file( file_name, my_list ):
  file_out  = open( file_name, 'w' );
  for each in my_list:
    file_out.write( each + "\n" );
  file_out.close();
  return;


def make_gtkw( module_name,in_list,out_list,int_list,win_width,win_height):
#  [comp_foo.gtkw]
#    [*]
#    [size] 1900 900
#    -Inputs
#    comp_foo.reset
#    -Outputs
#    comp_foo.q0[7:0]
  gtkw_list  = [];
  gtkw_list += ["[*]"];
  gtkw_list += ["[size] %d %d" % ( win_width, win_height ) ];
  gtkw_list += ["-"+module_name];
  for my_list in [ in_list, out_list, int_list ]:
    if ( my_list ):
      if   ( my_list == in_list  ):  txt = "-Inputs:"; 
      elif ( my_list == out_list ):  txt = "-Outputs:"; 
      elif ( my_list == int_list ):  txt = "-Internals:"; 
      gtkw_list += [ txt ];
      gtkw_list += [ module_name +"."+each_net for each_net in my_list ];
  return gtkw_list;
  

def parse_verilog( verilog_file ):
  verilog_list = file2list( verilog_file ); # foo.v
  first_always = None;
  first_module = None;
  for ( i, each_line ) in enumerate( verilog_list ):
    if ( first_module == None ):
      words = " ".join(each_line.split()).split(' ') + [None] * 4;
      if ( words[0] == "module" ):
        first_module = i;
    if ( first_always == None ):
      words = " ".join(each_line.split()).split(' ') + [None] * 4;
      if ( words[0] == "always" ):
        first_always = i;
  parse_list = verilog_list[first_module:first_always];
  in_list = [];
  out_list = [];
  int_list = [];
  for each_line in parse_list:
    each_line = each_line.replace(","," ");
    each_line = each_line.replace(";"," ");
    words = " ".join(each_line.split()).split(' ') + [None] * 8;
    # "output wire [7:0]" to "output wire [ 7 : 0 ]" to 
    if ( words[0] == "input"  or 
         words[0] == "output" or 
         words[0] == "inout"  or 
         words[0] == "wire"   or 
         words[0] == "reg"       ):  
      if ( "[" in each_line ):
        each_line = each_line.replace("["," [ ");
        each_line = each_line.replace(":"," : ");
        each_line = each_line.replace("]"," ] ");
    words = " ".join(each_line.split()).split(' ') + [None] * 8;
    net_name = None;
    if ( words[0] == "input"  or 
         words[0] == "output" or 
         words[0] == "inout"     ):  
      if ( "[" in each_line ):
        #          foo          [        7        :        0        ]
        net_name = words[7]+words[2]+words[3]+words[4]+words[5]+words[6];
      else:
        net_name = words[2];
    elif ( words[0] == "reg"  or 
           words[0] == "wire"     ):  
      if ( "[" in each_line ):
        #          foo          [        7        :        0        ]
        net_name = words[6]+words[1]+words[2]+words[3]+words[4]+words[5];
      else:
        net_name = words[1];
    list_ptr = None;
    if   ( words[0] == "input"  or 
           words[0] == "inout"     ):
      list_ptr = in_list;
    elif ( words[0] == "output"  ):
      list_ptr = out_list;
    elif ( words[0] == "reg"    or 
           words[0] == "wire"      ):
      list_ptr = int_list;
    if ( net_name != None and list_ptr != None ):
      list_ptr += [ net_name ];

  return ( in_list, out_list, int_list );

try:
  if __name__=='__main__': main()
except KeyboardInterrupt:
  print 'Break!'
