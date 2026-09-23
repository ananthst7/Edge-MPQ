`timescale 1ns/1ps
module int4_dot_hier (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output wire signed [31:0] result
);
    wire signed [7:0] prod [0:15];
    reg  signed [31:0] sum;
    integer i;

    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : G_MUL4
            smul4_hier m (.a(a[g*4 +: 4]), .b(b[g*4 +: 4]), .p(prod[g]));
        end
    endgenerate

    always @* begin
        sum = 32'sd0;
        for (i = 0; i < 16; i = i + 1)
            sum = sum + prod[i];
    end
    assign result = sum;
endmodule
