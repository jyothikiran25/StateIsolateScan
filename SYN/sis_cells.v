// ------------------------------------------------------------
// sis_cells.v : the three SIS cells from Fig. 2 of the paper
// (State-Isolated Scan, Ravikumar & Kushal) + a normal scan flop
// ------------------------------------------------------------
`timescale 1ns/1ps

// ISR cell = ISR_a (q_scan, shift stage) + ISR_b (q, hold stage)
module dff_isr (clk, scanen, loaden, scanin, q, q_scan);
  input clk, scanen, loaden, scanin;
  output reg q, q_scan;
  always @(posedge clk) begin
    if (loaden == 1'b0 && scanen == 1'b1)
      q_scan <= scanin;          // shift inside ISR_a
    else if (loaden == 1'b1 && scanen == 1'b0)
      q <= q_scan;               // transfer ISR_a -> ISR_b
  end
endmodule

// MUXDFF = functional state flop
module dmux_ff (clk, mux_sel, scanin, d_in, q);
  input clk, mux_sel, scanin, d_in;
  output reg q;
  always @(posedge clk) begin
    if (mux_sel == 1'b1)
      q <= d_in;                 // capture next-state from logic
    else
      q <= scanin;               // load test vector from ISR_b
  end
endmodule

// OSR cell = output scan isolation register
module dff_osr (clk, loaden, scan_in, d_in, q_scan);
  input clk, loaden, scan_in, d_in;
  output reg q_scan;
  always @(posedge clk) begin
    if (loaden == 1'b1)
      q_scan <= d_in;            // capture state
    else
      q_scan <= scan_in;         // shift towards ScanOut
  end
endmodule

// Conventional muxed-D scan flop (for the reference design)
module scan_dff (clk, se, si, d, q);
  input clk, se, si, d;
  output reg q;
  always @(posedge clk) begin
    if (se) q <= si;
    else    q <= d;
  end
endmodule
