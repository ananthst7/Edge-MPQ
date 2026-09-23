`timescale 1ns/1ps

// PicoRV32 PCPI wrapper for custom mixed-precision dot-product instructions.
//
// This standalone wrapper follows the PicoRV32 PCPI handshake:
//   pcpi_valid : processor presents an unsupported/custom instruction
//   pcpi_insn  : 32-bit instruction word
//   pcpi_rs1   : source register 1
//   pcpi_rs2   : source register 2
//   pcpi_wr    : write result back to rd
//   pcpi_rd    : result data
//   pcpi_wait  : stall CPU while coprocessor is working
//   pcpi_ready : instruction completed
//
// Custom encoding chosen for this project:
//   opcode = 7'b0001011  (CUSTOM-0)
//   funct3 = 3'b000      INT2 packed dot
//   funct3 = 3'b001      INT4 packed dot
//   funct3 = 3'b010      INT8 packed dot
//
// rs1 and rs2 are 32-bit PicoRV32 registers. To keep the first PCPI
// integration simple, this wrapper performs packed dot products over
// 32-bit operands:
//   INT2 => 16 lanes
//   INT4 =>  8 lanes
//   INT8 =>  4 lanes
//
// The verified 64-bit hierarchical datapath is reused by zero/sign-neutral
// extension into the low 32 bits; upper bits are zero. This preserves the
// arithmetic implementation while matching RV32 register width.
module mpq_pcpi (
    input  wire        clk,
    input  wire        resetn,

    input  wire        pcpi_valid,
    input  wire [31:0] pcpi_insn,
    input  wire [31:0] pcpi_rs1,
    input  wire [31:0] pcpi_rs2,

    output reg         pcpi_wr,
    output reg  [31:0] pcpi_rd,
    output wire        pcpi_wait,
    output reg         pcpi_ready
);

    localparam [6:0] OPCODE_CUSTOM0 = 7'b0001011;

    wire is_custom = (pcpi_insn[6:0] == OPCODE_CUSTOM0);

    reg [1:0] precision;
    reg       supported;

    always @* begin
        precision = 2'b11;
        supported = 1'b0;

        if (is_custom) begin
            case (pcpi_insn[14:12])
                3'b000: begin precision = 2'b00; supported = 1'b1; end // DOT2
                3'b001: begin precision = 2'b01; supported = 1'b1; end // DOT4
                3'b010: begin precision = 2'b10; supported = 1'b1; end // DOT8
                default: begin precision = 2'b11; supported = 1'b0; end
            endcase
        end
    end

    // Reuse the verified 64-bit dot-product hierarchy.
    // Upper halves are zero so only the packed RV32 lanes contribute.
    wire signed [31:0] dot_result;

    mpq_dot_hier u_dot (
        .a({32'b0, pcpi_rs1}),
        .b({32'b0, pcpi_rs2}),
        .precision(precision),
        .result(dot_result)
    );

    // First version is combinational / one-cycle-complete:
    // when a supported PCPI instruction is valid, assert ready and wr.
    assign pcpi_wait = 1'b0;

    always @* begin
        pcpi_wr    = 1'b0;
        pcpi_ready = 1'b0;
        pcpi_rd    = 32'b0;

        if (resetn && pcpi_valid && supported) begin
            pcpi_wr    = 1'b1;
            pcpi_ready = 1'b1;
            pcpi_rd    = dot_result;
        end
    end

endmodule
