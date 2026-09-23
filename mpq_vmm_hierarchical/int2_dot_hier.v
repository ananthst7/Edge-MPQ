`timescale 1ns/1ps
module int2_dot_hier (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output wire signed [31:0] result
);
    wire signed [3:0] prod [0:31];
    reg  signed [31:0] sum;
    integer i;

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : G_MUL2
            smul2_hier m (.a(a[g*2 +: 2]), .b(b[g*2 +: 2]), .p(prod[g]));
        end
    endgenerate

    always @* begin
        sum = 32'sd0;
        for (i = 0; i < 32; i = i + 1)
            sum = sum + prod[i];
    end
    assign result = sum;
endmodule
