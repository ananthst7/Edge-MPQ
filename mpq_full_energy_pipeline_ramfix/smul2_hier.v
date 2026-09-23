`timescale 1ns/1ps

// Signed two's-complement 2x2 multiplier using the unsigned 2-bit leaf
// product plus the standard signed-product correction terms.
module smul2_hier (
    input  wire [1:0] a,
    input  wire [1:0] b,
    output reg  signed [3:0] p
);
    wire [3:0] up;
    reg signed [5:0] t;

    umul2 u0 (.a(a), .b(b), .p(up));

    always @* begin
        t = $signed({2'b00, up});
        if (a[1]) t = t - $signed({2'b00, b, 2'b00});
        if (b[1]) t = t - $signed({2'b00, a, 2'b00});
        if (a[1] && b[1]) t = t + 6'sd16;
        p = t[3:0];
    end
endmodule
