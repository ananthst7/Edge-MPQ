`timescale 1ns/1ps
module tb_mpq_mac_hier;
    reg [63:0] a, b;
    reg [1:0] precision;
    reg signed [31:0] acc_in;
    wire signed [31:0] dot_out;
    wire signed [31:0] acc_out;

    integer i, t;
    integer errors;
    integer golden;
    integer va, vb;

    mpq_mac_hier dut (
        .a(a), .b(b), .precision(precision), .acc_in(acc_in),
        .dot_out(dot_out), .acc_out(acc_out)
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

    task check_current;
        input integer exp_dot;
        input integer exp_acc;
        begin
            #1;
            if ($signed(dot_out) !== exp_dot) begin
                $display("FAIL dot p=%b got=%0d expected=%0d a=%h b=%h", precision, $signed(dot_out), exp_dot, a, b);
                errors = errors + 1;
            end
            if ($signed(acc_out) !== exp_acc) begin
                $display("FAIL acc p=%b got=%0d expected=%0d", precision, $signed(acc_out), exp_acc);
                errors = errors + 1;
            end
        end
    endtask

    task random_test_int2;
        begin
            precision = 2'b00;
            for (t = 0; t < 100; t = t + 1) begin
                a = {$random, $random};
                b = {$random, $random};
                acc_in = $random;
                golden = 0;
                for (i = 0; i < 32; i = i + 1) begin
                    va = sx2(a[i*2 +: 2]);
                    vb = sx2(b[i*2 +: 2]);
                    golden = golden + va*vb;
                end
                check_current(golden, golden + acc_in);
            end
            $display("INT2 randomized tests complete");
        end
    endtask

    task random_test_int4;
        begin
            precision = 2'b01;
            for (t = 0; t < 100; t = t + 1) begin
                a = {$random, $random};
                b = {$random, $random};
                acc_in = $random;
                golden = 0;
                for (i = 0; i < 16; i = i + 1) begin
                    va = sx4(a[i*4 +: 4]);
                    vb = sx4(b[i*4 +: 4]);
                    golden = golden + va*vb;
                end
                check_current(golden, golden + acc_in);
            end
            $display("INT4 randomized tests complete");
        end
    endtask

    task random_test_int8;
        begin
            precision = 2'b10;
            for (t = 0; t < 100; t = t + 1) begin
                a = {$random, $random};
                b = {$random, $random};
                acc_in = $random;
                golden = 0;
                for (i = 0; i < 8; i = i + 1) begin
                    va = sx8(a[i*8 +: 8]);
                    vb = sx8(b[i*8 +: 8]);
                    golden = golden + va*vb;
                end
                check_current(golden, golden + acc_in);
            end
            $display("INT8 randomized tests complete");
        end
    endtask

    initial begin
        $dumpfile("mpq_mac_hier.vcd");
        $dumpvars(0, tb_mpq_mac_hier);
        errors = 0;
        a = 0; b = 0; precision = 0; acc_in = 0;

        // Directed INT8 example: [1..8] dot [8..1] = 120
        a = 64'h0807060504030201;
        b = 64'h0102030405060708;
        precision = 2'b10;
        acc_in = 32'sd10;
        check_current(120, 130);

        random_test_int2();
        random_test_int4();
        random_test_int8();

        // Reserved precision
        precision = 2'b11;
        a = 64'hDEADBEEF01234567;
        b = 64'h1122334455667788;
        acc_in = 32'sd123;
        check_current(0, 123);

        if (errors == 0)
            $display("\nALL HIERARCHICAL TESTS PASSED");
        else
            $display("\nFAILED: %0d errors", errors);

        $finish;
    end
endmodule
