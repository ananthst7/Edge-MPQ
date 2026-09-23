`timescale 1ns/1ps

// PicoRV32 + MPQ PCPI integration with debug visibility for event counting.
// The original picorv32.v remains unmodified.
module picorv32_mpq_top (
    input  wire        clk,
    input  wire        resetn,

    output wire        trap,

    output wire        mem_valid,
    output wire        mem_instr,
    input  wire        mem_ready,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,

    // Debug/event-monitor outputs
    output wire        dbg_pcpi_valid,
    output wire [31:0] dbg_pcpi_insn,
    output wire [31:0] dbg_pcpi_rs1,
    output wire [31:0] dbg_pcpi_rs2,
    output wire        dbg_pcpi_wr,
    output wire [31:0] dbg_pcpi_rd,
    output wire        dbg_pcpi_wait,
    output wire        dbg_pcpi_ready
);

    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;

    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;

    assign dbg_pcpi_valid = pcpi_valid;
    assign dbg_pcpi_insn  = pcpi_insn;
    assign dbg_pcpi_rs1   = pcpi_rs1;
    assign dbg_pcpi_rs2   = pcpi_rs2;
    assign dbg_pcpi_wr    = pcpi_wr;
    assign dbg_pcpi_rd    = pcpi_rd;
    assign dbg_pcpi_wait  = pcpi_wait;
    assign dbg_pcpi_ready = pcpi_ready;

    picorv32 #(
        .ENABLE_PCPI(1),
        .ENABLE_MUL(0),
        .ENABLE_FAST_MUL(0),
        .ENABLE_DIV(0),
        .COMPRESSED_ISA(0),
        .PROGADDR_RESET(32'h0000_0000),
        .PROGADDR_IRQ(32'h0000_0010)
    ) cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),

        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),

        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),

        .irq(32'b0)
    );

    mpq_pcpi accel (
        .clk(clk),
        .resetn(resetn),

        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),

        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready)
    );

endmodule
