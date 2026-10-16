// ------------------------------------------------------------------
// tb_secure.v : lifecycle-mode protection for SIS  (paper Sec. III-C)
//
//   sis_secure : wraps s27_sis with a lifecycle register that gates the
//                SIS control signals. The mode can only move forward
//                (MFG -> DEBUG -> SECURE), like one-time fuses.
//
//   mode       shift-in   transfer   shift-out
//   MFG  (0)    allowed    allowed    allowed     (factory test)
//   DEBUG(1)    allowed    blocked    blocked     (field debug)
//   SECURE(2)   blocked    blocked    blocked     (in the product)
//
//   The testbench plays an attacker who tries to READ the internal
//   state through scan, and to WRITE a chosen value into it.
// ------------------------------------------------------------------
`timescale 1ns/1ps

module sis_secure (clk, rst, req_mode, scanen_isr, loaden_isr, loaden_state,
                   loaden_osr, scan_in, G0, G1, G2, G3, G17, scan_out, mode);
  input  clk, rst;
  input  [1:0] req_mode;
  input  scanen_isr, loaden_isr, loaden_state, loaden_osr, scan_in;
  input  G0, G1, G2, G3;
  output G17, scan_out;
  output reg [1:0] mode;

  // lifecycle register : can only advance, never go back
  always @(posedge clk or posedge rst)
    if (rst)                  mode <= 2'd0;
    else if (req_mode > mode) mode <= req_mode;

  wire allow_shift_in  = (mode != 2'd2);
  wire allow_transfer  = (mode == 2'd0);
  wire allow_shift_out = (mode == 2'd0);

  // gated SIS controls
  wire scanen_g = scanen_isr & allow_shift_in;
  wire ld_isr_g = loaden_isr & allow_transfer;
  wire ld_st_g  = allow_transfer ? loaden_state : 1'b1;   // else: state is always functional
  wire ld_osr_g = loaden_osr & allow_shift_out;
  wire so_raw;

  s27_sis CORE (.clk(clk), .scanen_isr(scanen_g), .loaden_isr(ld_isr_g),
                .loaden_state(ld_st_g), .loaden_osr(ld_osr_g), .scan_in(scan_in),
                .G0(G0), .G1(G1), .G2(G2), .G3(G3), .G17(G17), .scan_out(so_raw));

  assign scan_out = so_raw & allow_shift_out;
endmodule

module tb_secure;
  reg clk = 0, rst = 1;
  reg [1:0] req_mode = 0;
  reg scanen = 0, ld_isr = 0, ld_st = 1, ld_osr = 0, si = 0;
  reg G0 = 0, G1 = 0, G2 = 0, G3 = 0;
  wire G17, so;
  wire [1:0] mode;
  reg  [2:0] secret, readout, after;
  integer k, errors = 0;

  sis_secure DUT (.clk(clk), .rst(rst), .req_mode(req_mode), .scanen_isr(scanen),
                  .loaden_isr(ld_isr), .loaden_state(ld_st), .loaden_osr(ld_osr),
                  .scan_in(si), .G0(G0), .G1(G1), .G2(G2), .G3(G3), .G17(G17),
                  .scan_out(so), .mode(mode));

  always #5 clk = ~clk;

  // the real internal state, read directly from inside (for checking only)
  wire [2:0] state  = {DUT.CORE.G7, DUT.CORE.G6, DUT.CORE.G5};
  wire [2:0] isr_a  = {DUT.CORE.qs3, DUT.CORE.qs2, DUT.CORE.qs1};

  // power-on reset of all flip-flops (real chips clear registers at power-up)
  task power_on;
    begin
      DUT.CORE.ISR1.q = 0; DUT.CORE.ISR1.q_scan = 0;
      DUT.CORE.ISR2.q = 0; DUT.CORE.ISR2.q_scan = 0;
      DUT.CORE.ISR3.q = 0; DUT.CORE.ISR3.q_scan = 0;
      DUT.CORE.MFF1.q = 0; DUT.CORE.MFF2.q = 0; DUT.CORE.MFF3.q = 0;
      DUT.CORE.OSR1.q_scan = 0; DUT.CORE.OSR2.q_scan = 0; DUT.CORE.OSR3.q_scan = 0;
    end
  endtask

  task scenario;
    input [1:0] m;
    input [8*6:1] name;
    begin
      // power-on, then program the lifecycle mode
      rst = 1; ld_st = 1; scanen = 0; ld_isr = 0; ld_osr = 0; si = 0;
      {G3,G2,G1,G0} = 4'b0000;
      @(negedge clk); power_on; rst = 0; req_mode = m;
      @(negedge clk);
      req_mode = 2'd0;                      // attacker tries to go BACK to MFG: ignored

      // normal operation: with G0=G1=1 the circuit settles into state 101
      {G3,G2,G1,G0} = 4'b0011;
      repeat (4) @(negedge clk);
      secret = state;                       // the value an attacker wants

      // ---- ATTACK 1 : read the state through scan ----
      ld_osr = 1; @(negedge clk);           // copy state -> OSR
      ld_osr = 0;
      for (k = 2; k >= 0; k = k - 1) begin readout[k] = so; @(negedge clk); end

      // ---- ATTACK 2 : write the chosen value 111 into the state ----
      scanen = 1;
      for (k = 2; k >= 0; k = k - 1) begin si = 1'b1; @(negedge clk); end
      scanen = 0; ld_isr = 1; @(negedge clk);   // ISR_a -> ISR_b
      ld_isr = 0; ld_st = 0;  @(negedge clk);   // ISR_b -> state
      ld_st = 1; after = state;

      $display("%s mode=%0d | secret=%b  read via scan=%b %s | write 111 -> ISR_a=%b state=%b %s",
        name, mode, secret, readout,
        (readout === secret) ? "LEAKED " : "BLOCKED",
        isr_a, after,
        (after === 3'b111) ? "OVERWRITTEN" : "BLOCKED");
    end
  endtask

  initial begin
    $display("-------------------------------------------------------------------------------------------------");
    scenario(2'd0, "MFG   ");
    scenario(2'd1, "DEBUG ");
    scenario(2'd2, "SECURE");
    $display("-------------------------------------------------------------------------------------------------");
    $display("Note: in every mode the testbench also tried to set the mode back to MFG; 'mode=' shows it stayed.");
    #20 $finish;
  end
endmodule
