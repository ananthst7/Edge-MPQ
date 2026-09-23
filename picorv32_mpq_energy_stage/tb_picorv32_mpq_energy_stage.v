`timescale 1ns/1ps

module tb_picorv32_mpq_energy_stage;

    reg clk;
    reg resetn;

    wire trap;

    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;

    wire        dbg_pcpi_valid;
    wire [31:0] dbg_pcpi_insn;
    wire [31:0] dbg_pcpi_rs1;
    wire [31:0] dbg_pcpi_rs2;
    wire        dbg_pcpi_wr;
    wire [31:0] dbg_pcpi_rd;
    wire        dbg_pcpi_wait;
    wire        dbg_pcpi_ready;

    reg [31:0] memory [0:255];

    integer i;
    integer cycles;
    integer errors;
    integer result_count;

    // Event counters
    integer instruction_fetches;
    integer dmem_reads;
    integer dmem_writes;
    integer custom_int2;
    integer custom_int4;
    integer custom_int8;
    integer arch_rf_reads;
    integer arch_rf_writes;
    integer packing_ops;

    integer f_events;

    localparam [31:0] RESULT2_ADDR = 32'h0000_0100;
    localparam [31:0] RESULT4_ADDR = 32'h0000_0104;
    localparam [31:0] RESULT8_ADDR = 32'h0000_0108;

    localparam signed [31:0] EXPECTED_DOT2 = 32'sd4;
    localparam signed [31:0] EXPECTED_DOT4 = 32'sd20;
    localparam signed [31:0] EXPECTED_DOT8 = 32'sd20;

    picorv32_mpq_top dut (
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

        .dbg_pcpi_valid(dbg_pcpi_valid),
        .dbg_pcpi_insn(dbg_pcpi_insn),
        .dbg_pcpi_rs1(dbg_pcpi_rs1),
        .dbg_pcpi_rs2(dbg_pcpi_rs2),
        .dbg_pcpi_wr(dbg_pcpi_wr),
        .dbg_pcpi_rd(dbg_pcpi_rd),
        .dbg_pcpi_wait(dbg_pcpi_wait),
        .dbg_pcpi_ready(dbg_pcpi_ready)
    );

    always #5 clk = ~clk;

    // Zero-wait-state memory.
    always @* begin
        mem_ready = 1'b0;
        mem_rdata = 32'b0;

        if (mem_valid) begin
            mem_ready = 1'b1;
            mem_rdata = memory[mem_addr[9:2]];
        end
    end

    // Architectural RF-access estimator based on retired/fetched instruction
    // semantics for this small straight-line firmware.
    //
    // IMPORTANT:
    // These are architectural operand accesses, not transistor-level
    // internal register-file toggles.
    task count_rf_for_instruction;
        input [31:0] insn;
        reg [6:0] opcode;
        reg [2:0] funct3;
        begin
            opcode = insn[6:0];
            funct3 = insn[14:12];

            case (opcode)
                7'b0110111: begin // LUI: rd write
                    arch_rf_writes = arch_rf_writes + 1;
                end

                7'b0010011: begin // OP-IMM: rs1 read + rd write
                    arch_rf_reads  = arch_rf_reads + 1;
                    arch_rf_writes = arch_rf_writes + 1;
                end

                7'b0001011: begin // CUSTOM-0 DOT*: rs1 + rs2 reads, rd write
                    arch_rf_reads  = arch_rf_reads + 2;
                    arch_rf_writes = arch_rf_writes + 1;
                end

                7'b0100011: begin // STORE: rs1(base) + rs2(data)
                    arch_rf_reads = arch_rf_reads + 2;
                end

                7'b1101111: begin // JAL: rd write unless rd=x0
                    if (insn[11:7] != 5'd0)
                        arch_rf_writes = arch_rf_writes + 1;
                end

                default: begin
                    // This test firmware contains no other executed types.
                end
            endcase
        end
    endtask

    task write_events_csv;
        begin
            f_events = $fopen("events.csv", "w");
            $fdisplay(f_events,
                "total_cycles,instruction_fetches,dmem_reads,dmem_writes,custom_int2,custom_int4,custom_int8,arch_rf_reads,arch_rf_writes,packing_ops");
            $fdisplay(f_events,
                "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                cycles,
                instruction_fetches,
                dmem_reads,
                dmem_writes,
                custom_int2,
                custom_int4,
                custom_int8,
                arch_rf_reads,
                arch_rf_writes,
                packing_ops);
            $fclose(f_events);
        end
    endtask

    always @(posedge clk) begin
        if (resetn)
            cycles <= cycles + 1;

        // Count accepted memory transactions.
        if (resetn && mem_valid && mem_ready) begin
            if (mem_instr) begin
                instruction_fetches = instruction_fetches + 1;
                count_rf_for_instruction(mem_rdata);
            end else begin
                if (|mem_wstrb)
                    dmem_writes = dmem_writes + 1;
                else
                    dmem_reads = dmem_reads + 1;
            end
        end

        // Count completed custom MPQ operations exactly at PCPI handshake.
        if (resetn && dbg_pcpi_valid && dbg_pcpi_ready) begin
            case (dbg_pcpi_insn[14:12])
                3'b000: custom_int2 = custom_int2 + 1;
                3'b001: custom_int4 = custom_int4 + 1;
                3'b010: custom_int8 = custom_int8 + 1;
                default: ;
            endcase

            $display("PCPI COMPLETE: funct3=%b rs1=%h rs2=%h rd=%0d cycle=%0d",
                     dbg_pcpi_insn[14:12],
                     dbg_pcpi_rs1,
                     dbg_pcpi_rs2,
                     $signed(dbg_pcpi_rd),
                     cycles);
        end

        // Apply memory writes.
        if (mem_valid && mem_ready && |mem_wstrb) begin
            if (mem_wstrb[0])
                memory[mem_addr[9:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1])
                memory[mem_addr[9:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2])
                memory[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3])
                memory[mem_addr[9:2]][31:24] <= mem_wdata[31:24];

            if (mem_addr == RESULT2_ADDR) begin
                $display("DOT2 RESULT: %0d at cycle %0d",
                         $signed(mem_wdata), cycles);
                if ($signed(mem_wdata) !== EXPECTED_DOT2) begin
                    $display("FAIL DOT2: expected %0d", EXPECTED_DOT2);
                    errors = errors + 1;
                end
                result_count = result_count + 1;
            end

            if (mem_addr == RESULT4_ADDR) begin
                $display("DOT4 RESULT: %0d at cycle %0d",
                         $signed(mem_wdata), cycles);
                if ($signed(mem_wdata) !== EXPECTED_DOT4) begin
                    $display("FAIL DOT4: expected %0d", EXPECTED_DOT4);
                    errors = errors + 1;
                end
                result_count = result_count + 1;
            end

            if (mem_addr == RESULT8_ADDR) begin
                $display("DOT8 RESULT: %0d at cycle %0d",
                         $signed(mem_wdata), cycles);
                if ($signed(mem_wdata) !== EXPECTED_DOT8) begin
                    $display("FAIL DOT8: expected %0d", EXPECTED_DOT8);
                    errors = errors + 1;
                end
                result_count = result_count + 1;

                write_events_csv();

                $display("\n--- EVENT SUMMARY ---");
                $display("cycles              = %0d", cycles);
                $display("instruction fetches = %0d", instruction_fetches);
                $display("data memory reads   = %0d", dmem_reads);
                $display("data memory writes  = %0d", dmem_writes);
                $display("INT2 custom ops     = %0d", custom_int2);
                $display("INT4 custom ops     = %0d", custom_int4);
                $display("INT8 custom ops     = %0d", custom_int8);
                $display("arch RF reads       = %0d", arch_rf_reads);
                $display("arch RF writes      = %0d", arch_rf_writes);
                $display("packing ops         = %0d", packing_ops);

                if (errors == 0 && result_count == 3)
                    $display("\nALL PICORV32 INT2/INT4/INT8 TESTS PASSED");
                else
                    $display("\nFAILED: errors=%0d result_count=%0d",
                             errors, result_count);

                #1;
                $finish;
            end
        end

        if (trap) begin
            $display("FAIL: PicoRV32 entered trap at cycle %0d", cycles);
            errors = errors + 1;
            write_events_csv();
            #1;
            $finish;
        end

        if (cycles > 1500) begin
            $display("FAIL: simulation timeout");
            errors = errors + 1;
            write_events_csv();
            #1;
            $finish;
        end
    end

    initial begin
        $dumpfile("picorv32_mpq_energy_stage.vcd");
        $dumpvars(0, tb_picorv32_mpq_energy_stage);

        clk = 0;
        resetn = 0;

        cycles = 0;
        errors = 0;
        result_count = 0;

        instruction_fetches = 0;
        dmem_reads = 0;
        dmem_writes = 0;
        custom_int2 = 0;
        custom_int4 = 0;
        custom_int8 = 0;
        arch_rf_reads = 0;
        arch_rf_writes = 0;

        // Inputs are pre-packed constants in this micro-test.
        // Therefore no runtime packing instructions are executed yet.
        packing_ops = 0;

        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h0000_0013; // NOP

        // x1 = 0x04030201
        memory[0]  = 32'h0403_00b7; // lui  x1,0x04030
        memory[1]  = 32'h2010_8093; // addi x1,x1,0x201

        // x2 = 0x01020304
        memory[2]  = 32'h0102_0137; // lui  x2,0x01020
        memory[3]  = 32'h3041_0113; // addi x2,x2,0x304

        // Same packed 32-bit inputs interpreted at three precisions.
        // DOT2 x3,x1,x2 => 4
        memory[4]  = 32'h0020_818b;

        // DOT4 x4,x1,x2 => 20
        memory[5]  = 32'h0020_920b;

        // DOT8 x5,x1,x2 => 20
        memory[6]  = 32'h0020_a28b;

        // Expose results through normal RV32 stores.
        memory[7]  = 32'h1030_2023; // sw x3,0x100(x0)
        memory[8]  = 32'h1040_2223; // sw x4,0x104(x0)
        memory[9]  = 32'h1050_2423; // sw x5,0x108(x0)

        memory[10] = 32'h0000_006f; // jal x0,0

        #20;
        resetn = 1;
    end

endmodule
