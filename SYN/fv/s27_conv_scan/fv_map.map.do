
//input ports
add mapped point clk clk -type PI PI
add mapped point scan_en scan_en -type PI PI
add mapped point scan_in scan_in -type PI PI
add mapped point G0 G0 -type PI PI
add mapped point G1 G1 -type PI PI
add mapped point G2 G2 -type PI PI
add mapped point G3 G3 -type PI PI

//output ports
add mapped point G17 G17 -type PO PO
add mapped point scan_out scan_out -type PO PO

//inout ports




//Sequential Pins
add mapped point FF1/q/q FF1_q_reg/Q -type DFF DFF
add mapped point FF2/q/q FF2_q_reg/Q -type DFF DFF
add mapped point FF3/q/q FF3_q_reg/Q -type DFF DFF



//Black Boxes



//Empty Modules as Blackboxes
