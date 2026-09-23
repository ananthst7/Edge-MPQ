`timescale 1ns/1ps

// Signed two's-complement 8x8 multiplier.
// Magnitude product is explicitly hierarchical: 8-bit -> 4-bit -> 2-bit.
module smul8_hier (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output reg  signed [15:0] p
);
    wire [15:0] up;
    reg signed [17:0] t;

    umul8_hier u0 (.a(a), .b(b), .p(up));

    always @* begin
        t = $signed({2'b00, up});
        if (a[7]) t = t - $signed({2'b00, b, 8'b00000000});
        if (b[7]) t = t - $signed({2'b00, a, 8'b00000000});
        if (a[7] && b[7]) t = t + 18'sd65536;
        p = t[15:0];
    end
endmodule
