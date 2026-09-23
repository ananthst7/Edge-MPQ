`timescale 1ns/1ps

// 4-bit UNSIGNED multiplier built only from four 2-bit leaf multipliers.
module umul4_hier (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] p
);
    wire [3:0] p_ll, p_lh, p_hl, p_hh;

    umul2 m0 (.a(a[1:0]), .b(b[1:0]), .p(p_ll));
    umul2 m1 (.a(a[1:0]), .b(b[3:2]), .p(p_lh));
    umul2 m2 (.a(a[3:2]), .b(b[1:0]), .p(p_hl));
    umul2 m3 (.a(a[3:2]), .b(b[3:2]), .p(p_hh));

    assign p = {4'b0000, p_ll}
             + ({4'b0000, p_lh} << 2)
             + ({4'b0000, p_hl} << 2)
             + ({4'b0000, p_hh} << 4);
endmodule
