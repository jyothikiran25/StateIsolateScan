// ------------------------------------------------------------------
// tb_atspeed.v : at-speed (transition-delay) testing of s27 with SIS
//   Paper Sec. II-B : Launch-Off-Shift (LOS) and Launch-Off-Capture (LOC)
//
//   GOOD   : s27_sis        (from s27_sis.v, no delays)
//   FAULTY : s27_sis_slow   (below) - same circuit, but gate U8 (node G11)
//            is SLOW-TO-RISE: it takes 5 ns to rise (a delay defect)
//
//   Each test is run twice:
//     fast capture : launch edge -> capture edge = 2 ns  (at speed)
//     slow capture : launch edge -> capture edge = 20 ns (scan speed)
//   Expected: the defect is DETECTED at speed and MISSED at slow speed.
//   Vectors/responses are written {G7,G6,G5}.
// ------------------------------------------------------------------
`timescale 1ns/100ps

// ---------- faulty copy of s27_sis : G11 is slow-to-rise ----------
module s27_sis_slow (clk, scanen_isr, loaden_isr, loaden_state, loaden_osr,
                     scan_in, G0, G1, G2, G3, G17, scan_out);
  input  clk, scanen_isr, loaden_isr, loaden_state, loaden_osr;
  input  scan_in, G0, G1, G2, G3;
  output G17, scan_out;
  wire G5, G6, G7, G8, G9, G10, G11, G12, G13, G14, G15, G16;
  wire qs1, qs2, qs3, q1, q2, q3, o1, o2, o3;
  not  U1 (G14, G0);
  not  U2 (G17, G11);
  and  U3 (G8,  G14, G6);
  or   U4 (G15, G12, G8);
  or   U5 (G16, G3,  G8);
  nand U6 (G9,  G16, G15);
  nor  U7 (G10, G14, G11);
  nor  #(5,0) U8 (G11, G5, G9);      // <<< DELAY DEFECT: rise 5 ns, fall 0 ns
  nor  U9 (G12, G1,  G7);
  nor  U10(G13, G2,  G12);
  dff_isr ISR1 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(scan_in), .q(q1), .q_scan(qs1));
  dff_isr ISR2 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(qs1),     .q(q2), .q_scan(qs2));
  dff_isr ISR3 (.clk(clk), .scanen(scanen_isr), .loaden(loaden_isr), .scanin(qs2),     .q(q3), .q_scan(qs3));
  dmux_ff MFF1 (.clk(clk), .mux_sel(loaden_state), .scanin(q1), .d_in(G10), .q(G5));
  dmux_ff MFF2 (.clk(clk), .mux_sel(loaden_state), .scanin(q2), .d_in(G11), .q(G6));
  dmux_ff MFF3 (.clk(clk), .mux_sel(loaden_state), .scanin(q3), .d_in(G13), .q(G7));
  dff_osr OSR1 (.clk(clk), .loaden(loaden_osr), .scan_in(1'b0), .d_in(G5), .q_scan(o1));
  dff_osr OSR2 (.clk(clk), .loaden(loaden_osr), .scan_in(o1),   .d_in(G6), .q_scan(o2));
  dff_osr OSR3 (.clk(clk), .loaden(loaden_osr), .scan_in(o2),   .d_in(G7), .q_scan(o3));
  assign scan_out = o3;
endmodule

// ------------------------------- testbench -------------------------------
module tb_atspeed;
  reg clk = 0;
  reg scanen = 0, ld_isr = 0, ld_st = 0, ld_osr = 0, si = 0;
  reg G0 = 0, G1 = 0, G2 = 0, G3 = 0;
  wire G17_g, so_g, G17_f, so_f;
  reg [2:0] rg, rf;              // responses: good, faulty
  integer k;

  s27_sis      GOOD  (.clk(clk), .scanen_isr(scanen), .loaden_isr(ld_isr), .loaden_state(ld_st),
                      .loaden_osr(ld_osr), .scan_in(si), .G0(G0), .G1(G1), .G2(G2), .G3(G3),
                      .G17(G17_g), .scan_out(so_g));
  s27_sis_slow FAULTY(.clk(clk), .scanen_isr(scanen), .loaden_isr(ld_isr), .loaden_state(ld_st),
                      .loaden_osr(ld_osr), .scan_in(si), .G0(G0), .G1(G1), .G2(G2), .G3(G3),
                      .G17(G17_f), .scan_out(so_f));

  // one clock pulse : wait 'gap' ns, rise, stay high 0.5 ns, fall
  // (controls are changed right after the pulse, while clk is low)
  task pulse;
    input real gap;
    begin #(gap) clk = 1; #0.5 clk = 0; end
  endtask

  // shift V into ISR_a (G7 bit first), slow clock
  task shift_in;
    input [2:0] v;
    begin
      scanen = 1; ld_isr = 0; ld_st = 0; ld_osr = 0;
      for (k = 2; k >= 0; k = k - 1) begin si = v[k]; pulse(19.5); end
      scanen = 0;
    end
  endtask

  // ISR_a -> ISR_b, then ISR_b -> state register (slow)
  task transfer;
    begin
      ld_isr = 1; pulse(19.5);         // ISR_a -> ISR_b
      ld_isr = 0; ld_st = 0; pulse(19.5); // ISR_b -> MUXDFF (state)
    end
  endtask

  // copy state -> OSR, then shift response out (slow)
  task unload;
    begin
      ld_st = 0; ld_osr = 1; pulse(19.5);  // OSR <- state
      ld_osr = 0;
      for (k = 2; k >= 0; k = k - 1) begin
        rg[k] = so_g; rf[k] = so_f; pulse(19.5);
      end
    end
  endtask

  task show;
    input [8*4:1] name; input real gap; input [2:0] expv;
    begin
      $display("%s capture after %4.1f ns : expected=%b  good=%b  faulty=%b  -> %s%s",
               name, gap, expv, rg, rf,
               (rg === expv) ? "good OK, " : "good WRONG, ",
               (rf !== rg)   ? "DEFECT DETECTED" : "defect MISSED");
    end
  endtask

  // ---------------- LOS : launch off shift ----------------
  // V1 = {G7,G6,G5} = 100, one extra shift of 0 gives V2 = 000
  task los_test;
    input real gap;
    begin
      {G3,G2,G1,G0} = 4'b1000;              // primary inputs held constant
      shift_in(3'b100);                     // 1) V1 -> ISR_a
      transfer;                             // 2) V1 -> ISR_b -> state
      scanen = 1; si = 0; pulse(19.5);      // 3) one shift : V2 in ISR_a
      scanen = 0; ld_isr = 1; pulse(19.5);  // 4a) V2 -> ISR_b
      ld_isr = 0; ld_st = 0; pulse(19.5);   // 4b) LAUNCH : state <- V2
      ld_st = 1; pulse(gap - 0.5);          // 5) CAPTURE response (at speed or slow)
      unload;                               // 6) OSR -> scan out
      show("LOS ", gap, 3'b010);
    end
  endtask

  // ---------------- LOC : launch off capture ----------------
  // V1 = 100, with G2=G3=1 the first capture gives V2 = 000
  task loc_test;
    input real gap;
    begin
      {G3,G2,G1,G0} = 4'b1100;
      shift_in(3'b100);                     // 1) V1 -> ISR_a
      transfer;                             // 2) V1 -> ISR_b -> state
      ld_st = 1; pulse(19.5);               // 3) LAUNCH : slow functional capture, state <- V2
      ld_st = 1; pulse(gap - 0.5);          // 4) CAPTURE response (at speed or slow)
      unload;                               // 5) OSR -> scan out
      show("LOC ", gap, 3'b010);
    end
  endtask

  initial begin
    $display("------------------------------------------------------------------------------");
    $display(" At-speed test of s27 (SIS). FAULTY circuit: node G11 slow-to-rise (5 ns)");
    $display("------------------------------------------------------------------------------");
    los_test(2.0);
    los_test(20.0);
    loc_test(2.0);
    loc_test(20.0);
    $display("------------------------------------------------------------------------------");
    #50 $finish;
  end
endmodule
