// ------------------------------------------------------------
// s27_sis.v : ISCAS89 s27 with STATE-ISOLATED SCAN (SIS)
// scan_in -> ISR1 -> ISR2 -> ISR3      (shift-in path, ISR_a)
// ISRk.q  -> MUXDFFk -> logic          (functional state)
// MUXDFFk.q -> OSRk ; OSR1 -> OSR2 -> OSR3 -> scan_out
// ------------------------------------------------------------
`timescale 1ns/1ps
module s27_sis (clk, scanen_isr, loaden_isr, loaden_state, loaden_osr,
                scan_in, G0, G1, G2, G3, G17, scan_out);
  input  clk, scanen_isr, loaden_isr, loaden_state, loaden_osr;
  input  scan_in, G0, G1, G2, G3;
  output G17, scan_out;

  wire G5, G6, G7;                               // state flops (MUXDFF)
  wire G8, G9, G10, G11, G12, G13, G14, G15, G16; // logic nodes
  wire qs1, qs2, qs3;                            // ISR_a outputs (q_scan)
  wire q1,  q2,  q3;                             // ISR_b outputs (q)
  wire o1,  o2,  o3;                             // OSR outputs

  // ---- s27 combinational logic (same as original) ----
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

  // ---- Input Scan Isolation Register ----
  dff_isr ISR1 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(scan_in), .q(q1), .q_scan(qs1));
  dff_isr ISR2 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(qs1),     .q(q2), .q_scan(qs2));
  dff_isr ISR3 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(qs2),     .q(q3), .q_scan(qs3));

  // ---- Functional state register ----
  dmux_ff MFF1 (.clk(clk), .mux_sel(loaden_state), .scanin(q1), .d_in(G10), .q(G5));
  dmux_ff MFF2 (.clk(clk), .mux_sel(loaden_state), .scanin(q2), .d_in(G11), .q(G6));
  dmux_ff MFF3 (.clk(clk), .mux_sel(loaden_state), .scanin(q3), .d_in(G13), .q(G7));

  // ---- Output Scan Isolation Register ----
  dff_osr OSR1 (.clk(clk), .loaden(loaden_osr), .scan_in(1'b0), .d_in(G5), .q_scan(o1));
  dff_osr OSR2 (.clk(clk), .loaden(loaden_osr), .scan_in(o1),   .d_in(G6), .q_scan(o2));
  dff_osr OSR3 (.clk(clk), .loaden(loaden_osr), .scan_in(o2),   .d_in(G7), .q_scan(o3));

  assign scan_out = o3;
endmodule
