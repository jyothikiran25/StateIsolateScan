// ------------------------------------------------------------
// tb_s27.v : testbench comparing conventional scan and SIS on s27
//  Phase 1 : conventional scan   (clk_c runs)
//  Phase 2 : state-isolated scan (clk_s runs)
//  - checks the scanned-out response against the expected next state
//  - counts toggles on the combinational nodes during scan SHIFT
// A test vector / response is written as {G7,G6,G5}
// ------------------------------------------------------------
`timescale 1ns/1ps
module tb_s27;
  parameter NT = 6;                 // number of test patterns

  reg clk, run_c, run_s;
  wire clk_c = clk & run_c;         // clock of conventional design
  wire clk_s = clk & run_s;         // clock of SIS design

  reg G0, G1, G2, G3;               // primary inputs (shared)
  reg scan_in;

  reg  scan_en;                     // conventional scan control
  wire G17_c, so_c;

  reg  scanen_isr, loaden_isr, loaden_state, loaden_osr;  // SIS controls
  wire G17_s, so_s;

  s27_conv_scan u_conv (.clk(clk_c), .scan_en(scan_en), .scan_in(scan_in),
                        .G0(G0), .G1(G1), .G2(G2), .G3(G3),
                        .G17(G17_c), .scan_out(so_c));

  s27_sis u_sis (.clk(clk_s), .scanen_isr(scanen_isr), .loaden_isr(loaden_isr),
                 .loaden_state(loaden_state), .loaden_osr(loaden_osr),
                 .scan_in(scan_in), .G0(G0), .G1(G1), .G2(G2), .G3(G3),
                 .G17(G17_s), .scan_out(so_s));

  initial clk = 0;
  always #5 clk = ~clk;             // 10 ns clock

  // ---------------- test patterns ----------------
  reg [2:0] vec [0:NT-1];           // state input  {G7,G6,G5}
  reg [3:0] pin [0:NT-1];           // PI input     {G3,G2,G1,G0}
  reg [2:0] exp_ns;                 // expected next state
  reg       exp_po;                 // expected G17
  reg [2:0] resp;
  integer i, k, errors;

  initial begin
    vec[0]=3'b101; pin[0]=4'b0000;
    vec[1]=3'b010; pin[1]=4'b0110;
    vec[2]=3'b111; pin[2]=4'b1001;
    vec[3]=3'b001; pin[3]=4'b0011;
    vec[4]=3'b110; pin[4]=4'b1100;
    vec[5]=3'b000; pin[5]=4'b1010;
  end

  // golden model of the s27 logic
  task expected;
    input [2:0] s; input [3:0] p;
    reg g5,g6,g7,g0,g1,g2,g3,g8,g9,g10,g11,g12,g13,g14,g15,g16;
    begin
      {g7,g6,g5} = s;  {g3,g2,g1,g0} = p;
      g14 = ~g0;        g8  = g14 & g6;
      g12 = ~(g1 | g7); g15 = g12 | g8;   g16 = g3 | g8;
      g9  = ~(g16 & g15);
      g11 = ~(g5 | g9); g10 = ~(g14 | g11); g13 = ~(g2 | g12);
      exp_ns = {g13, g11, g10};
      exp_po = ~g11;
    end
  endtask

  // ---------------- toggle counters (shift only) ----------------
  integer tog_c, tog_s;
  initial begin tog_c = 0; tog_s = 0; end
  wire sh_c = run_c & scan_en;
  wire sh_s = run_s & scanen_isr;

  always @(u_conv.G8)  if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G9)  if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G10) if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G11) if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G12) if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G13) if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G15) if (sh_c) tog_c = tog_c + 1;
  always @(u_conv.G16) if (sh_c) tog_c = tog_c + 1;

  always @(u_sis.G8)   if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G9)   if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G10)  if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G11)  if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G12)  if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G13)  if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G15)  if (sh_s) tog_s = tog_s + 1;
  always @(u_sis.G16)  if (sh_s) tog_s = tog_s + 1;

  // ---------------- conventional scan test ----------------
  // shift 3 (response of previous test comes out) -> capture 1
  task conv_test;
    input integer n;
    begin
      for (k = 2; k >= 0; k = k - 1) begin
        @(negedge clk); scan_en = 1; scan_in = vec[n][k];
        resp[k] = so_c;                       // previous response
      end
      if (n > 0) check("CONV", n-1);
      @(negedge clk); scan_en = 0; {G3,G2,G1,G0} = pin[n];   // capture
      expected(vec[n], pin[n]);
      #1 if (G17_c !== exp_po) begin
        errors = errors + 1; $display("CONV test %0d : G17 MISMATCH", n);
      end
    end
  endtask

  // ---------------- SIS test (N+4 cycles) ----------------
  task sis_test;
    input integer n;
    begin
      // 1) shift V into ISR_a ; previous response leaves through OSR
      for (k = 2; k >= 0; k = k - 1) begin
        @(negedge clk); scanen_isr = 1; loaden_isr = 0; loaden_state = 0;
        loaden_osr = 0; scan_in = vec[n][k];
        resp[k] = so_s;
      end
      if (n > 0) check("SIS ", n-1);
      // 2) transfer ISR_a -> ISR_b
      @(negedge clk); scanen_isr = 0; loaden_isr = 1;
      // 3) transfer ISR_b -> MUXDFF, apply primary inputs
      @(negedge clk); loaden_isr = 0; {G3,G2,G1,G0} = pin[n];
      // 4) capture logic response into MUXDFF
      @(negedge clk); loaden_state = 1;
      expected(vec[n], pin[n]);
      #1 if (G17_s !== exp_po) begin
        errors = errors + 1; $display("SIS  test %0d : G17 MISMATCH", n);
      end
      // 5) copy state into OSR
      @(negedge clk); loaden_state = 0; loaden_osr = 1;
    end
  endtask

  task check;
    input [31:0] name; input integer n;
    begin
      expected(vec[n], pin[n]);
      if (resp !== exp_ns) begin
        errors = errors + 1;
        $display("%s test %0d : vec=%b pi=%b  got=%b exp=%b  FAIL", name, n, vec[n], pin[n], resp, exp_ns);
      end else
        $display("%s test %0d : vec=%b pi=%b  response=%b  PASS", name, n, vec[n], pin[n], resp);
    end
  endtask

  // ---------------- main ----------------
  initial begin
    errors = 0; run_c = 0; run_s = 0;
    scan_en = 0; scan_in = 0; {G3,G2,G1,G0} = 4'b0000;
    scanen_isr = 0; loaden_isr = 0; loaden_state = 0; loaden_osr = 0;

    // ---- Phase 1 : conventional scan ----
    @(negedge clk); run_c = 1;
    for (i = 0; i < NT; i = i + 1) conv_test(i);
    for (k = 2; k >= 0; k = k - 1) begin        // flush last response
      @(negedge clk); scan_en = 1; scan_in = 0; resp[k] = so_c;
    end
    check("CONV", NT-1);
    @(negedge clk); run_c = 0; scan_en = 0;

    // ---- Phase 2 : state-isolated scan ----
    repeat (2) @(negedge clk);
    run_s = 1;
    for (i = 0; i < NT; i = i + 1) sis_test(i);
    for (k = 2; k >= 0; k = k - 1) begin        // flush last response
      @(negedge clk); scanen_isr = 1; loaden_osr = 0; scan_in = 0; resp[k] = so_s;
    end
    check("SIS ", NT-1);
    @(negedge clk); run_s = 0; scanen_isr = 0;

    $display("------------------------------------------------");
    $display("Logic-node toggles during scan shift:");
    $display("   Conventional scan : %0d", tog_c);
    $display("   State-isolated    : %0d", tog_s);
    $display("Errors = %0d", errors);
    $display("------------------------------------------------");
    #20 $finish;
  end
endmodule
