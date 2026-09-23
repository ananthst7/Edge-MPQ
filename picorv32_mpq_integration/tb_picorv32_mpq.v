`timescale 1ns/1ps

module tb_picorv32_mpq;

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

    reg [31:0] memory [0:255];

    integer i;
    integer cycles;
    integer errors;

    // Address used by firmware to expose the accelerator result.
    localparam [31:0] RESULT_ADDR = 32'h0000_0100;
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
        .mem_rdata(mem_rdata)
    );

    always #5 clk = ~clk;

    // Simple zero-wait-state memory.
    always @* begin
        mem_ready = 1'b0;
        mem_rdata = 32'b0;

        if (mem_valid) begin
            mem_ready = 1'b1;
            mem_rdata = memory[mem_addr[9:2]];
        end
    end

    // Apply writes according to byte strobes and detect firmware result.
    always @(posedge clk) begin
        if (resetn)
            cycles <= cycles + 1;

        if (mem_valid && mem_ready && |mem_wstrb) begin
            if (mem_wstrb[0])
                memory[mem_addr[9:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1])
                memory[mem_addr[9:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2])
                memory[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3])
                memory[mem_addr[9:2]][31:24] <= mem_wdata[31:24];

            if (mem_addr == RESULT_ADDR) begin
                $display("RESULT WRITE: addr=%h data=%0d (0x%08h) cycles=%0d",
                         mem_addr, $signed(mem_wdata), mem_wdata, cycles);

                if ($signed(mem_wdata) === EXPECTED_DOT8) begin
                    $display("\nPICORV32 + MPQ PCPI DOT8 TEST PASSED");
                end else begin
                    $display("\nFAIL: got %0d expected %0d",
                             $signed(mem_wdata), EXPECTED_DOT8);
                    errors = errors + 1;
                end

                #1;
                $finish;
            end
        end

        if (trap) begin
            $display("FAIL: PicoRV32 entered trap at cycle %0d", cycles);
            errors = errors + 1;
            #1;
            $finish;
        end

        if (cycles > 1000) begin
            $display("FAIL: simulation timeout");
            errors = errors + 1;
            #1;
            $finish;
        end
    end

    initial begin
        $dumpfile("picorv32_mpq.vcd");
        $dumpvars(0, tb_picorv32_mpq);

        clk = 0;
        resetn = 0;
        cycles = 0;
        errors = 0;

        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h0000_0013; // NOP: addi x0,x0,0

        // Tiny hand-encoded firmware:
        //
        // x1 = 0x04030201  => INT8 lanes [1,2,3,4]
        // x2 = 0x01020304  => INT8 lanes [4,3,2,1]
        //
        // DOT8 x3,x1,x2
        // result = 1*4 + 2*3 + 3*2 + 4*1 = 20
        //
        // sw x3, 0x100(x0)
        //
        // Instruction 4 uses:
        // opcode CUSTOM-0 = 0001011
        // funct3 = 010 (DOT8)
        // rd=x3, rs1=x1, rs2=x2

        memory[0] = 32'h0403_00b7; // lui  x1,0x04030
        memory[1] = 32'h2010_8093; // addi x1,x1,0x201
        memory[2] = 32'h0102_0137; // lui  x2,0x01020
        memory[3] = 32'h3041_0113; // addi x2,x2,0x304
        memory[4] = 32'h0020_a18b; // custom DOT8 x3,x1,x2
        memory[5] = 32'h1030_2023; // sw   x3,0x100(x0)
        memory[6] = 32'h0000_006f; // jal  x0,0

        #20;
        resetn = 1;
    end

endmodule
