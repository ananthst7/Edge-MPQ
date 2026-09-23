`timescale 1ns/1ps

// 4-output mixed-precision vector-matrix multiply.
//
// One 64-bit packed activation vector is multiplied against four
// independently packed 64-bit weight rows.
//
// precision:
//   2'b00 -> INT2 : (1x32) * (32x4)
//   2'b01 -> INT4 : (1x16) * (16x4)
//   2'b10 -> INT8 : (1x8)  * (8x4)
//   2'b11 -> reserved, all outputs forced to zero
//
// Each output is a signed 32-bit dot product.
module mpq_vmm4_hier (
    input  wire [63:0] activation,
    input  wire [63:0] weight0,
    input  wire [63:0] weight1,
    input  wire [63:0] weight2,
    input  wire [63:0] weight3,
    input  wire [1:0]  precision,

    output wire signed [31:0] out0,
    output wire signed [31:0] out1,
    output wire signed [31:0] out2,
    output wire signed [31:0] out3
);

    mpq_dot_hier dot0 (
        .a(activation),
        .b(weight0),
        .precision(precision),
        .result(out0)
    );

    mpq_dot_hier dot1 (
        .a(activation),
        .b(weight1),
        .precision(precision),
        .result(out1)
    );

    mpq_dot_hier dot2 (
        .a(activation),
        .b(weight2),
        .precision(precision),
        .result(out2)
    );

    mpq_dot_hier dot3 (
        .a(activation),
        .b(weight3),
        .precision(precision),
        .result(out3)
    );

endmodule
