`timescale 1ns/1ps

// Signed two's-complement 4x4 multiplier.
// Magnitude product is explicitly hierarchical: 4-bit -> 2-bit leaves.
module smul4_hier (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  signed [7:0] p
);
    wire [7:0] up;
    reg signed [9:0] t;

    umul4_hier u0 (.a(a), .b(b), .p(up));

    always @* begin
        t = $signed({2'b00, up});
        if (a[3]) t = t - $signed({2'b00, b, 4'b0000});
        if (b[3]) t = t - $signed({2'b00, a, 4'b0000});
        if (a[3] && b[3]) t = t + 10'sd256;
        p = t[7:0];
    end
endmodule
