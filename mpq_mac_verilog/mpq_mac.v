`timescale 1ns/1ps

module mpq_mac (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [1:0]  precision,
    input  wire signed [31:0] acc_in,
    output wire signed [31:0] dot_out,
    output wire signed [31:0] acc_out
);
    mpq_dot u_dot (
        .a(a),
        .b(b),
        .precision(precision),
        .result(dot_out)
    );

    assign acc_out = acc_in + dot_out;
endmodule
