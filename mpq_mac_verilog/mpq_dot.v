`timescale 1ns/1ps

module mpq_dot (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [1:0]  precision,
    output reg  signed [31:0] result
);
    localparam PREC_INT2 = 2'b00;
    localparam PREC_INT4 = 2'b01;
    localparam PREC_INT8 = 2'b10;

    wire signed [31:0] result_int2;
    wire signed [31:0] result_int4;
    wire signed [31:0] result_int8;

    int2_dot u_int2 (.a(a), .b(b), .result(result_int2));
    int4_dot u_int4 (.a(a), .b(b), .result(result_int4));
    int8_dot u_int8 (.a(a), .b(b), .result(result_int8));

    always @* begin
        case (precision)
            PREC_INT2: result = result_int2;
            PREC_INT4: result = result_int4;
            PREC_INT8: result = result_int8;
            default:   result = 32'sd0;
        endcase
    end
endmodule
