`timescale 1ns/1ps

module tb_full_energy_pipeline;

    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;

    wire trap;
    wire mem_valid, mem_instr;
    reg mem_ready;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata;

    wire dbg_pcpi_valid, dbg_pcpi_wr, dbg_pcpi_wait, dbg_pcpi_ready;
    wire [31:0] dbg_pcpi_insn, dbg_pcpi_rs1, dbg_pcpi_rs2, dbg_pcpi_rd;

    reg [31:0] memory [0:32767];

    integer cycles = 0;
    integer instruction_fetches = 0;
    integer dmem_reads = 0;
    integer dmem_writes = 0;
    integer rf_reads = 0;
    integer rf_writes = 0;

    integer custom_int2 = 0;
    integer custom_int4 = 0;
    integer custom_int8 = 0;

    integer packing_alu_ops = 0;
    integer packing_loads = 0;
    integer packing_stores = 0;

    integer gemm_stack_loads = 0;
    integer gemm_stack_stores = 0;
    integer all_stack_loads = 0;
    integer all_stack_stores = 0;
    integer gemm_marker_starts = 0;
    integer gemm_marker_ends = 0;

    integer pack_active = 0;
    integer gemm_active = 0;

    integer f;
    integer i;
    reg [1023:0] fwfile;
    reg [1023:0] outfile;

    localparam [31:0] MARK_PACK_START = 32'h0001FF00;
    localparam [31:0] MARK_PACK_END   = 32'h0001FF04;
    localparam [31:0] MARK_GEMM_START= 32'h0001FF08;
    localparam [31:0] MARK_GEMM_END  = 32'h0001FF0C;
    localparam [31:0] RESULT_DOT2    = 32'h0001FF10;
    localparam [31:0] RESULT_DOT4    = 32'h0001FF14;
    localparam [31:0] RESULT_DOT8    = 32'h0001FF18;
    localparam [31:0] RESULT_CHECKSUM= 32'h0001FF1C;
    localparam [31:0] MARK_DONE      = 32'h0001FF20;

    picorv32_mpq_top dut (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .dbg_pcpi_valid(dbg_pcpi_valid),
        .dbg_pcpi_insn(dbg_pcpi_insn),
        .dbg_pcpi_rs1(dbg_pcpi_rs1),
        .dbg_pcpi_rs2(dbg_pcpi_rs2),
        .dbg_pcpi_wr(dbg_pcpi_wr),
        .dbg_pcpi_rd(dbg_pcpi_rd),
        .dbg_pcpi_wait(dbg_pcpi_wait),
        .dbg_pcpi_ready(dbg_pcpi_ready)
    );

    function is_mmio;
        input [31:0] a;
        begin
            is_mmio = (a >= 32'h0001FF00 && a <= 32'h0001FF3F);
        end
    endfunction

    function is_stack;
        input [31:0] a;
        begin
            // crt0 sets SP = 0x1F000.
            // Allow a generous 4 KB window below SP to capture compiler
            // stack frames for all pressure levels.
            is_stack = (a >= 32'h0001E000 && a < 32'h0001F000);
        end
    endfunction

    task count_rf;
        input [31:0] insn;
        reg [6:0] op;
        begin
            op = insn[6:0];
            case (op)
                7'b0110111, // LUI
                7'b0010111: begin // AUIPC
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b1101111: begin // JAL
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b1100111: begin // JALR
                    rf_reads = rf_reads + 1;
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b1100011: rf_reads = rf_reads + 2; // branch
                7'b0000011: begin // load
                    rf_reads = rf_reads + 1;
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b0100011: rf_reads = rf_reads + 2; // store
                7'b0010011: begin // op-imm
                    rf_reads = rf_reads + 1;
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b0110011: begin // op / mul
                    rf_reads = rf_reads + 2;
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                7'b0001011: begin // custom dot
                    rf_reads = rf_reads + 2;
                    if (insn[11:7] != 0) rf_writes = rf_writes + 1;
                end
                default: ;
            endcase
        end
    endtask

    function is_packing_alu;
        input [31:0] insn;
        reg [6:0] op;
        begin
            op = insn[6:0];
            // Count only non-memory integer ALU instructions in the packing
            // region to avoid double-counting loads/stores under E_memory.
            is_packing_alu = (op == 7'b0010011 || op == 7'b0110011);
        end
    endfunction

    task write_csv;
        begin
            f = $fopen(outfile, "w");
            $fdisplay(f,
"total_cycles,instruction_fetches,dmem_reads,dmem_writes,custom_int2,custom_int4,custom_int8,rf_reads,rf_writes,packing_alu_ops,packing_loads,packing_stores,all_stack_loads,all_stack_stores,gemm_stack_loads,gemm_stack_stores,gemm_marker_starts,gemm_marker_ends");
            $fdisplay(f,
"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
cycles,instruction_fetches,dmem_reads,dmem_writes,
custom_int2,custom_int4,custom_int8,
rf_reads,rf_writes,
packing_alu_ops,packing_loads,packing_stores,
all_stack_loads,all_stack_stores,
gemm_stack_loads,gemm_stack_stores,
gemm_marker_starts,gemm_marker_ends);
            $fclose(f);
        end
    endtask

    always @* begin
        mem_ready = 0;
        mem_rdata = 0;
        if (mem_valid) begin
            mem_ready = 1;
            if (!is_mmio(mem_addr))
                mem_rdata = memory[mem_addr[16:2]];
        end
    end

    always @(posedge clk) begin
        if (resetn)
            cycles <= cycles + 1;

        if (resetn && mem_valid && mem_ready) begin
            if (mem_instr) begin
                instruction_fetches = instruction_fetches + 1;
                count_rf(mem_rdata);

                if (pack_active && is_packing_alu(mem_rdata))
                    packing_alu_ops = packing_alu_ops + 1;
            end else if (!is_mmio(mem_addr)) begin
                if (|mem_wstrb) begin
                    dmem_writes = dmem_writes + 1;
                    if (pack_active) packing_stores = packing_stores + 1;

                    if (is_stack(mem_addr))
                        all_stack_stores = all_stack_stores + 1;

                    if (gemm_active && is_stack(mem_addr))
                        gemm_stack_stores = gemm_stack_stores + 1;
                end else begin
                    dmem_reads = dmem_reads + 1;
                    if (pack_active) packing_loads = packing_loads + 1;

                    if (is_stack(mem_addr))
                        all_stack_loads = all_stack_loads + 1;

                    if (gemm_active && is_stack(mem_addr))
                        gemm_stack_loads = gemm_stack_loads + 1;
                end
            end
        end

        if (resetn && dbg_pcpi_valid) begin
            $display("PCPI ACTIVE cycle=%0d pc=%08x insn=%08x funct3=%b ready=%b wr=%b wait=%b",
                     cycles, dut.cpu.reg_pc, dbg_pcpi_insn,
                     dbg_pcpi_insn[14:12],
                     dbg_pcpi_ready, dbg_pcpi_wr, dbg_pcpi_wait);
        end

        if (resetn && dbg_pcpi_valid && dbg_pcpi_ready) begin
            case (dbg_pcpi_insn[14:12])
                3'b000: custom_int2 = custom_int2 + 1;
                3'b001: custom_int4 = custom_int4 + 1;
                3'b010: custom_int8 = custom_int8 + 1;
                default: ;
            endcase
        end

        if (resetn && mem_valid && mem_ready && |mem_wstrb && is_mmio(mem_addr)) begin
            case (mem_addr)
                MARK_PACK_START: pack_active = 1;
                MARK_PACK_END:   pack_active = 0;
                MARK_GEMM_START: begin
                    gemm_active = 1;
                    gemm_marker_starts = gemm_marker_starts + 1;
                    $display("GEMM START marker at cycle %0d", cycles);
                end
                MARK_GEMM_END: begin
                    gemm_active = 0;
                    gemm_marker_ends = gemm_marker_ends + 1;
                    $display("GEMM END marker at cycle %0d", cycles);
                end

                RESULT_DOT2:
                    $display("DOT2 RESULT = %0d", $signed(mem_wdata));
                RESULT_DOT4:
                    $display("DOT4 RESULT = %0d", $signed(mem_wdata));
                RESULT_DOT8:
                    $display("DOT8 RESULT = %0d", $signed(mem_wdata));
                RESULT_CHECKSUM:
                    $display("GEMM CHECKSUM = %0d", $signed(mem_wdata));

                MARK_DONE: begin
                    $display("\n--- DYNAMIC EVENT SUMMARY ---");
                    $display("cycles             = %0d", cycles);
                    $display("RF reads/writes    = %0d / %0d", rf_reads, rf_writes);
                    $display("data reads/writes  = %0d / %0d", dmem_reads, dmem_writes);
                    $display("custom 2/4/8       = %0d / %0d / %0d",
                             custom_int2, custom_int4, custom_int8);
                    $display("packing ALU ops    = %0d", packing_alu_ops);
                    $display("packing loads      = %0d", packing_loads);
                    $display("packing stores     = %0d", packing_stores);
                    $display("ALL stack loads    = %0d", all_stack_loads);
                    $display("ALL stack stores   = %0d", all_stack_stores);
                    $display("GEMM stack loads   = %0d", gemm_stack_loads);
                    $display("GEMM stack stores  = %0d", gemm_stack_stores);
                    $display("GEMM markers S/E   = %0d / %0d", gemm_marker_starts, gemm_marker_ends);
                    write_csv();
                    $display("Wrote %0s", outfile);
                    #1 $finish;
                end
            endcase
        end

        if (trap) begin
            $display("\nFAIL: CPU TRAP");
            $display("  cycle       = %0d", cycles);
            $display("  cpu reg_pc  = 0x%08x", dut.cpu.reg_pc);
            $display("  dbg insn pc = 0x%08x", dut.cpu.dbg_insn_addr);
            $display("  dbg insn    = 0x%08x", dut.cpu.dbg_insn_opcode);
            $display("  pcpi_valid  = %b", dbg_pcpi_valid);
            $display("  pcpi_insn   = 0x%08x", dbg_pcpi_insn);
            $display("  pcpi_ready  = %b", dbg_pcpi_ready);
            $display("  pcpi_wr     = %b", dbg_pcpi_wr);
            $display("  pcpi_wait   = %b", dbg_pcpi_wait);
            write_csv();
            #1 $finish;
        end

        if (cycles > 200000) begin
            $display("FAIL: timeout");
            write_csv();
            #1 $finish;
        end
    end

    initial begin
        if (!$value$plusargs("firmware=%s", fwfile))
            fwfile = "build/fw_full.hex";

        if (!$value$plusargs("events=%s", outfile))
            outfile = "events_full.csv";

        for (i = 0; i < 32768; i = i + 1)
            memory[i] = 32'h00000013;

        $display("Loading firmware: %0s", fwfile);
        $readmemh(fwfile, memory);

        $dumpfile("full_energy_pipeline.vcd");
        $dumpvars(0, tb_full_energy_pipeline);

        #20 resetn = 1;
    end

endmodule
