`timescale 1ns/1ps

// 8-bit UNSIGNED multiplier built from four hierarchical 4-bit multipliers.
module umul8_hier (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] p
);
    wire [7:0] p_ll, p_lh, p_hl, p_hh;

    umul4_hier m0 (.a(a[3:0]), .b(b[3:0]), .p(p_ll));
    umul4_hier m1 (.a(a[3:0]), .b(b[7:4]), .p(p_lh));
    umul4_hier m2 (.a(a[7:4]), .b(b[3:0]), .p(p_hl));
    umul4_hier m3 (.a(a[7:4]), .b(b[7:4]), .p(p_hh));

    assign p = {8'b0, p_ll}
             + ({8'b0, p_lh} << 4)
             + ({8'b0, p_hl} << 4)
             + ({8'b0, p_hh} << 8);
endmodule
