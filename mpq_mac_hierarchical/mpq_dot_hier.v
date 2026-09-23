`timescale 1ns/1ps
module mpq_dot_hier (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [1:0]  precision,
    output reg  signed [31:0] result
);
    localparam PREC_INT2 = 2'b00;
    localparam PREC_INT4 = 2'b01;
    localparam PREC_INT8 = 2'b10;

    wire signed [31:0] r2, r4, r8;

    int2_dot_hier d2 (.a(a), .b(b), .result(r2));
    int4_dot_hier d4 (.a(a), .b(b), .result(r4));
    int8_dot_hier d8 (.a(a), .b(b), .result(r8));

    always @* begin
        case (precision)
            PREC_INT2: result = r2;
            PREC_INT4: result = r4;
            PREC_INT8: result = r8;
            default:   result = 32'sd0;
        endcase
    end
endmodule
