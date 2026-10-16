
//input ports
add mapped point clk clk -type PI PI
add mapped point scanen_isr scanen_isr -type PI PI
add mapped point loaden_isr loaden_isr -type PI PI
add mapped point loaden_state loaden_state -type PI PI
add mapped point loaden_osr loaden_osr -type PI PI
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
add mapped point MFF1/q/q MFF1_q_reg/Q -type DFF DFF
add mapped point MFF2/q/q MFF2_q_reg/Q -type DFF DFF
add mapped point OSR3/q_scan/q OSR3_q_scan_reg/Q -type DFF DFF
add mapped point OSR2/q_scan/q OSR2_q_scan_reg/Q -type DFF DFF
add mapped point MFF3/q/q MFF3_q_reg/Q -type DFF DFF
add mapped point ISR1/q/q ISR1_q_reg/Q -type DFF DFF
add mapped point ISR2/q/q ISR2_q_reg/Q -type DFF DFF
add mapped point ISR2/q_scan/q ISR2_q_scan_reg/Q -type DFF DFF
add mapped point ISR3/q/q ISR3_q_reg/Q -type DFF DFF
add mapped point ISR3/q_scan/q ISR3_q_scan_reg/Q -type DFF DFF
add mapped point ISR1/q_scan/q ISR1_q_scan_reg/Q -type DFF DFF
add mapped point OSR1/q_scan/q OSR1_q_scan_reg/Q -type DFF DFF



//Black Boxes



//Empty Modules as Blackboxes
