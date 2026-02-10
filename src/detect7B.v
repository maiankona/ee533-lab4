////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : detect7B.vf
// /___/   /\     Timestamp : 02/01/2026 15:08:46
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w C:/Xilinx/10.1/ISE/ISEexamples/lab3_testing/detect7B.sch detect7B.vf
//Design Name: detect7B
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module detect7B(ce, 
                clk, 
                hwregA, 
                match_en, 
                mrst, 
                pipe1, 
                match, 
                pipe0);

    input ce;
    input clk;
    input [63:0] hwregA;
    input match_en;
    input mrst;
    input [71:0] pipe1;
   output match;
    inout [71:0] pipe0;
   
   wire XLXN_10;
   wire [111:0] XLXN_13;
   wire XLXN_16;
   wire XLXN_22;
   wire match_DUMMY;
   
   assign match = match_DUMMY;
   busmerge XLXI_3 (.da(pipe0[47:0]), 
                    .db(pipe1[63:0]), 
                    .q(XLXN_13[111:0]));
   FD XLXI_4 (.C(clk), 
              .D(mrst), 
              .Q(XLXN_10));
   defparam XLXI_4.INIT = 1'b0;
   FDCE XLXI_5 (.C(clk), 
                .CE(XLXN_22), 
                .CLR(XLXN_10), 
                .D(XLXN_22), 
                .Q(match_DUMMY));
   defparam XLXI_5.INIT = 1'b0;
   AND3B1 XLXI_6 (.I0(match_DUMMY), 
                  .I1(match_en), 
                  .I2(XLXN_16), 
                  .O(XLXN_22));
   reg9B XLXI_7 (.ce(ce), 
                 .clk(clk), 
                 .clr(XLXN_10), 
                 .d(pipe1[71:0]), 
                 .q(pipe0[71:0]));
   wordmatch XLXI_8 (.datacomp(hwregA[55:0]), 
                     .datain(XLXN_13[111:0]), 
                     .wildcard(hwregA[62:56]), 
                     .match(XLXN_16));
endmodule
