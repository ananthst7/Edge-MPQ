`timescale 1ns/1ps

// 2-bit UNSIGNED leaf multiplier.
// Deliberately written without the '*' operator so wider multipliers can be
// constructed explicitly from this primitive.
module umul2 (
    input  wire [1:0] a,
    input  wire [1:0] b,
    output wire [3:0] p
);
    wire [3:0] a_ext = {2'b00, a};
    assign p = (b[0] ? a_ext : 4'b0000) +
               (b[1] ? (a_ext << 1) : 4'b0000);
endmodule
