`timescale 1ns/1ps

module int8_dot (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  signed [31:0] result
);
    integer i;
    reg signed [7:0] a_elem;
    reg signed [7:0] b_elem;
    reg signed [15:0] product;
    reg signed [31:0] sum;

    always @* begin
        sum = 32'sd0;
        for (i = 0; i < 8; i = i + 1) begin
            a_elem = $signed(a[i*8 +: 8]);
            b_elem = $signed(b[i*8 +: 8]);
            product = a_elem * b_elem;
            sum = sum + product;
        end
        result = sum;
    end
endmodule
