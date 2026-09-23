`timescale 1ns/1ps

module tb_mpq_vmm4_hier;

    reg  [63:0] activation;
    reg  [63:0] weight0, weight1, weight2, weight3;
    reg  [1:0]  precision;

    wire signed [31:0] out0, out1, out2, out3;

    integer errors;
    integer t;
    integer exp0, exp1, exp2, exp3;

    mpq_vmm4_hier dut (
        .activation(activation),
        .weight0(weight0),
        .weight1(weight1),
        .weight2(weight2),
        .weight3(weight3),
        .precision(precision),
        .out0(out0),
        .out1(out1),
        .out2(out2),
        .out3(out3)
    );

    function integer sx2;
        input [1:0] x;
        begin
            sx2 = x[1] ? (x - 4) : x;
        end
    endfunction

    function integer sx4;
        input [3:0] x;
        begin
            sx4 = x[3] ? (x - 16) : x;
        end
    endfunction

    function integer sx8;
        input [7:0] x;
        begin
            sx8 = x[7] ? (x - 256) : x;
        end
    endfunction

    function integer ref_dot2;
        input [63:0] a;
        input [63:0] b;
        integer i;
        begin
            ref_dot2 = 0;
            for (i = 0; i < 32; i = i + 1)
                ref_dot2 = ref_dot2
                         + sx2(a[i*2 +: 2]) * sx2(b[i*2 +: 2]);
        end
    endfunction

    function integer ref_dot4;
        input [63:0] a;
        input [63:0] b;
        integer i;
        begin
            ref_dot4 = 0;
            for (i = 0; i < 16; i = i + 1)
                ref_dot4 = ref_dot4
                         + sx4(a[i*4 +: 4]) * sx4(b[i*4 +: 4]);
        end
    endfunction

    function integer ref_dot8;
        input [63:0] a;
        input [63:0] b;
        integer i;
        begin
            ref_dot8 = 0;
            for (i = 0; i < 8; i = i + 1)
                ref_dot8 = ref_dot8
                         + sx8(a[i*8 +: 8]) * sx8(b[i*8 +: 8]);
        end
    endfunction

    task check_outputs;
        input integer e0;
        input integer e1;
        input integer e2;
        input integer e3;
        begin
            #1;

            if ($signed(out0) !== e0) begin
                $display("FAIL out0 p=%b got=%0d expected=%0d",
                         precision, $signed(out0), e0);
                errors = errors + 1;
            end
            if ($signed(out1) !== e1) begin
                $display("FAIL out1 p=%b got=%0d expected=%0d",
                         precision, $signed(out1), e1);
                errors = errors + 1;
            end
            if ($signed(out2) !== e2) begin
                $display("FAIL out2 p=%b got=%0d expected=%0d",
                         precision, $signed(out2), e2);
                errors = errors + 1;
            end
            if ($signed(out3) !== e3) begin
                $display("FAIL out3 p=%b got=%0d expected=%0d",
                         precision, $signed(out3), e3);
                errors = errors + 1;
            end
        end
    endtask

    task randomize_inputs;
        begin
            // $random is 32 bits, so concatenate two calls for 64 bits.
            activation = {$random, $random};
            weight0    = {$random, $random};
            weight1    = {$random, $random};
            weight2    = {$random, $random};
            weight3    = {$random, $random};
        end
    endtask

    initial begin
        $dumpfile("mpq_vmm4_hier.vcd");
        $dumpvars(0, tb_mpq_vmm4_hier);

        errors = 0;

        // ------------------------------------------------------------
        // Directed INT8 test
        // activation bytes, low byte first: [1,2,3,4,5,6,7,8]
        // ------------------------------------------------------------
        precision  = 2'b10;
        activation = 64'h0807060504030201;

        // [8,7,6,5,4,3,2,1] -> 120
        weight0 = 64'h0102030405060708;

        // all +1 -> 36
        weight1 = 64'h0101010101010101;

        // all -1 -> -36
        weight2 = 64'hFFFFFFFFFFFFFFFF;

        // [1,-1,1,-1,1,-1,1,-1] -> -4
        weight3 = 64'hFF01FF01FF01FF01;

        exp0 = ref_dot8(activation, weight0);
        exp1 = ref_dot8(activation, weight1);
        exp2 = ref_dot8(activation, weight2);
        exp3 = ref_dot8(activation, weight3);

        check_outputs(exp0, exp1, exp2, exp3);

        $display("Directed INT8 VMM test complete: %0d %0d %0d %0d",
                 exp0, exp1, exp2, exp3);

        // ------------------------------------------------------------
        // 100 randomized INT2 VMM vectors
        // ------------------------------------------------------------
        precision = 2'b00;
        for (t = 0; t < 100; t = t + 1) begin
            randomize_inputs();

            exp0 = ref_dot2(activation, weight0);
            exp1 = ref_dot2(activation, weight1);
            exp2 = ref_dot2(activation, weight2);
            exp3 = ref_dot2(activation, weight3);

            check_outputs(exp0, exp1, exp2, exp3);
        end
        $display("INT2 VMM randomized tests complete");

        // ------------------------------------------------------------
        // 100 randomized INT4 VMM vectors
        // ------------------------------------------------------------
        precision = 2'b01;
        for (t = 0; t < 100; t = t + 1) begin
            randomize_inputs();

            exp0 = ref_dot4(activation, weight0);
            exp1 = ref_dot4(activation, weight1);
            exp2 = ref_dot4(activation, weight2);
            exp3 = ref_dot4(activation, weight3);

            check_outputs(exp0, exp1, exp2, exp3);
        end
        $display("INT4 VMM randomized tests complete");

        // ------------------------------------------------------------
        // 100 randomized INT8 VMM vectors
        // ------------------------------------------------------------
        precision = 2'b10;
        for (t = 0; t < 100; t = t + 1) begin
            randomize_inputs();

            exp0 = ref_dot8(activation, weight0);
            exp1 = ref_dot8(activation, weight1);
            exp2 = ref_dot8(activation, weight2);
            exp3 = ref_dot8(activation, weight3);

            check_outputs(exp0, exp1, exp2, exp3);
        end
        $display("INT8 VMM randomized tests complete");

        // ------------------------------------------------------------
        // Reserved precision must zero all four outputs
        // ------------------------------------------------------------
        precision = 2'b11;
        randomize_inputs();
        check_outputs(0, 0, 0, 0);
        $display("Reserved-precision VMM test complete");

        if (errors == 0)
            $display("\nALL VMM TESTS PASSED");
        else
            $display("\nFAILED: %0d errors", errors);

        #1;
        $finish;
    end

endmodule
