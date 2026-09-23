`timescale 1ns/1ps
module int8_dot_hier (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output wire signed [31:0] result
);
    wire signed [15:0] prod [0:7];
    reg  signed [31:0] sum;
    integer i;

    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : G_MUL8
            smul8_hier m (.a(a[g*8 +: 8]), .b(b[g*8 +: 8]), .p(prod[g]));
        end
    endgenerate

    always @* begin
        sum = 32'sd0;
        for (i = 0; i < 8; i = i + 1)
            sum = sum + prod[i];
    end
    assign result = sum;
endmodule
