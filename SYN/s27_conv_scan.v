// ------------------------------------------------------------
// s27_conv_scan.v : ISCAS89 s27 with CONVENTIONAL scan
// scan chain : scan_in -> G5 -> G6 -> G7 -> scan_out
// ------------------------------------------------------------
`timescale 1ns/1ps
module s27_conv_scan (clk, scan_en, scan_in, G0, G1, G2, G3, G17, scan_out);
  input  clk, scan_en, scan_in, G0, G1, G2, G3;
  output G17, scan_out;

  wire G5, G6, G7;                               // state flops
  wire G8, G9, G10, G11, G12, G13, G14, G15, G16; // logic nodes

  // ---- s27 combinational logic ----
  not  U1 (G14, G0);
  not  U2 (G17, G11);
  and  U3 (G8,  G14, G6);
  or   U4 (G15, G12, G8);
  or   U5 (G16, G3,  G8);
  nand U6 (G9,  G16, G15);
  nor  U7 (G10, G14, G11);
  nor  U8 (G11, G5,  G9);
  nor  U9 (G12, G1,  G7);
  nor  U10(G13, G2,  G12);

  // ---- scan flops ----
  scan_dff FF1 (.clk(clk), .se(scan_en), .si(scan_in), .d(G10), .q(G5));
  scan_dff FF2 (.clk(clk), .se(scan_en), .si(G5),      .d(G11), .q(G6));
  scan_dff FF3 (.clk(clk), .se(scan_en), .si(G6),      .d(G13), .q(G7));

  assign scan_out = G7;
endmodule
