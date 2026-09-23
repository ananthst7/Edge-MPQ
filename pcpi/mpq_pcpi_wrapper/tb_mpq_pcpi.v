`timescale 1ns/1ps

module tb_mpq_pcpi;

    reg clk;
    reg resetn;

    reg         pcpi_valid;
    reg [31:0]  pcpi_insn;
    reg [31:0]  pcpi_rs1;
    reg [31:0]  pcpi_rs2;

    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;

    integer errors;
    integer t;
    integer expected;

    localparam [6:0] OPCODE_CUSTOM0 = 7'b0001011;

    mpq_pcpi dut (
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

    always #5 clk = ~clk;

    function [31:0] make_insn;
        input [2:0] funct3;
        begin
            // funct7=0, rs2=0, rs1=0, funct3 selectable, rd=1, custom-0 opcode
            make_insn = {7'b0000000, 5'd0, 5'd0, funct3, 5'd1, OPCODE_CUSTOM0};
        end
    endfunction

    function integer sx2;
        input [1:0] x;
        begin sx2 = x[1] ? (x - 4) : x; end
    endfunction

    function integer sx4;
        input [3:0] x;
        begin sx4 = x[3] ? (x - 16) : x; end
    endfunction

    function integer sx8;
        input [7:0] x;
        begin sx8 = x[7] ? (x - 256) : x; end
    endfunction

    function integer ref_dot2_32;
        input [31:0] a;
        input [31:0] b;
        integer i;
        begin
            ref_dot2_32 = 0;
            for (i = 0; i < 16; i = i + 1)
                ref_dot2_32 = ref_dot2_32
                           + sx2(a[i*2 +: 2]) * sx2(b[i*2 +: 2]);
        end
    endfunction

    function integer ref_dot4_32;
        input [31:0] a;
        input [31:0] b;
        integer i;
        begin
            ref_dot4_32 = 0;
            for (i = 0; i < 8; i = i + 1)
                ref_dot4_32 = ref_dot4_32
                           + sx4(a[i*4 +: 4]) * sx4(b[i*4 +: 4]);
        end
    endfunction

    function integer ref_dot8_32;
        input [31:0] a;
        input [31:0] b;
        integer i;
        begin
            ref_dot8_32 = 0;
            for (i = 0; i < 4; i = i + 1)
                ref_dot8_32 = ref_dot8_32
                           + sx8(a[i*8 +: 8]) * sx8(b[i*8 +: 8]);
        end
    endfunction

    task check_supported;
        input [2:0] funct3;
        input [31:0] a;
        input [31:0] b;
        input integer exp;
        begin
            pcpi_insn  = make_insn(funct3);
            pcpi_rs1   = a;
            pcpi_rs2   = b;
            pcpi_valid = 1'b1;
            #1;

            if (pcpi_ready !== 1'b1) begin
                $display("FAIL ready funct3=%b", funct3);
                errors = errors + 1;
            end
            if (pcpi_wr !== 1'b1) begin
                $display("FAIL wr funct3=%b", funct3);
                errors = errors + 1;
            end
            if ($signed(pcpi_rd) !== exp) begin
                $display("FAIL rd funct3=%b got=%0d expected=%0d a=%h b=%h",
                         funct3, $signed(pcpi_rd), exp, a, b);
                errors = errors + 1;
            end

            pcpi_valid = 1'b0;
            #1;
        end
    endtask

    initial begin
        $dumpfile("mpq_pcpi.vcd");
        $dumpvars(0, tb_mpq_pcpi);

        clk        = 0;
        resetn     = 0;
        pcpi_valid = 0;
        pcpi_insn  = 0;
        pcpi_rs1   = 0;
        pcpi_rs2   = 0;
        errors     = 0;

        #12;
        resetn = 1;

        // Directed INT8:
        // a=[1,2,3,4], b=[4,3,2,1] => 20
        expected = ref_dot8_32(32'h04030201, 32'h01020304);
        check_supported(3'b010, 32'h04030201, 32'h01020304, expected);

        // Directed INT4
        expected = ref_dot4_32(32'h76543210, 32'h11111111);
        check_supported(3'b001, 32'h76543210, 32'h11111111, expected);

        // Directed INT2
        expected = ref_dot2_32(32'h1B1B1B1B, 32'h55555555);
        check_supported(3'b000, 32'h1B1B1B1B, 32'h55555555, expected);

        // 100 random tests at each supported precision.
        for (t = 0; t < 100; t = t + 1) begin
            pcpi_rs1 = $random;
            pcpi_rs2 = $random;
            expected = ref_dot2_32(pcpi_rs1, pcpi_rs2);
            check_supported(3'b000, pcpi_rs1, pcpi_rs2, expected);
        end
        $display("INT2 PCPI randomized tests complete");

        for (t = 0; t < 100; t = t + 1) begin
            pcpi_rs1 = $random;
            pcpi_rs2 = $random;
            expected = ref_dot4_32(pcpi_rs1, pcpi_rs2);
            check_supported(3'b001, pcpi_rs1, pcpi_rs2, expected);
        end
        $display("INT4 PCPI randomized tests complete");

        for (t = 0; t < 100; t = t + 1) begin
            pcpi_rs1 = $random;
            pcpi_rs2 = $random;
            expected = ref_dot8_32(pcpi_rs1, pcpi_rs2);
            check_supported(3'b010, pcpi_rs1, pcpi_rs2, expected);
        end
        $display("INT8 PCPI randomized tests complete");

        // Unsupported funct3 under CUSTOM-0 must not claim the instruction.
        pcpi_insn  = make_insn(3'b111);
        pcpi_rs1   = 32'h12345678;
        pcpi_rs2   = 32'h87654321;
        pcpi_valid = 1'b1;
        #1;

        if (pcpi_ready !== 1'b0 || pcpi_wr !== 1'b0) begin
            $display("FAIL unsupported custom instruction was claimed");
            errors = errors + 1;
        end

        pcpi_valid = 1'b0;

        // Non-custom opcode must also be ignored.
        pcpi_insn = 32'h00000033; // ordinary R-type opcode
        pcpi_valid = 1'b1;
        #1;
        if (pcpi_ready !== 1'b0 || pcpi_wr !== 1'b0) begin
            $display("FAIL normal instruction was claimed by PCPI");
            errors = errors + 1;
        end

        pcpi_valid = 1'b0;

        if (errors == 0)
            $display("\nALL PCPI WRAPPER TESTS PASSED");
        else
            $display("\nFAILED: %0d errors", errors);

        #10;
        $finish;
    end

endmodule
