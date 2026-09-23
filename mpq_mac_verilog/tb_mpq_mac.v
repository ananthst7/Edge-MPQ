`timescale 1ns/1ps

module tb_mpq_mac;
    reg [63:0] a;
    reg [63:0] b;
    reg [1:0] precision;
    reg signed [31:0] acc_in;

    wire signed [31:0] dot_out;
    wire signed [31:0] acc_out;

    integer i;
    integer errors;
    integer expected;
    integer ref_sum;

    reg signed [7:0] v8_a [0:7];
    reg signed [7:0] v8_b [0:7];
    reg signed [3:0] v4_a [0:15];
    reg signed [3:0] v4_b [0:15];
    reg signed [1:0] v2_a [0:31];
    reg signed [1:0] v2_b [0:31];

    mpq_mac dut (
        .a(a),
        .b(b),
        .precision(precision),
        .acc_in(acc_in),
        .dot_out(dot_out),
        .acc_out(acc_out)
    );

    task check_result;
        input integer expected_dot;
        input integer expected_acc;
        begin
            #1;
            if ($signed(dot_out) !== expected_dot) begin
                $display("FAIL dot: precision=%b expected=%0d got=%0d", precision, expected_dot, $signed(dot_out));
                errors = errors + 1;
            end else begin
                $display("PASS dot: precision=%b result=%0d", precision, $signed(dot_out));
            end

            if ($signed(acc_out) !== expected_acc) begin
                $display("FAIL acc: precision=%b expected=%0d got=%0d", precision, expected_acc, $signed(acc_out));
                errors = errors + 1;
            end else begin
                $display("PASS acc: precision=%b result=%0d", precision, $signed(acc_out));
            end
        end
    endtask

    task pack_int8;
        begin
            a = 64'd0;
            b = 64'd0;
            for (i = 0; i < 8; i = i + 1) begin
                a[i*8 +: 8] = v8_a[i];
                b[i*8 +: 8] = v8_b[i];
            end
        end
    endtask

    task pack_int4;
        begin
            a = 64'd0;
            b = 64'd0;
            for (i = 0; i < 16; i = i + 1) begin
                a[i*4 +: 4] = v4_a[i];
                b[i*4 +: 4] = v4_b[i];
            end
        end
    endtask

    task pack_int2;
        begin
            a = 64'd0;
            b = 64'd0;
            for (i = 0; i < 32; i = i + 1) begin
                a[i*2 +: 2] = v2_a[i];
                b[i*2 +: 2] = v2_b[i];
            end
        end
    endtask

    initial begin
        $dumpfile("mpq_mac.vcd");
        $dumpvars(0, tb_mpq_mac);

        errors = 0;
        a = 0;
        b = 0;
        precision = 0;
        acc_in = 0;

        // ------------------------------------------------------------
        // TEST 1: INT8
        // A = [1,2,3,4,5,6,7,8]
        // B = [8,7,6,5,4,3,2,1]
        // dot = 120
        // ------------------------------------------------------------
        v8_a[0]=1; v8_a[1]=2; v8_a[2]=3; v8_a[3]=4;
        v8_a[4]=5; v8_a[5]=6; v8_a[6]=7; v8_a[7]=8;
        v8_b[0]=8; v8_b[1]=7; v8_b[2]=6; v8_b[3]=5;
        v8_b[4]=4; v8_b[5]=3; v8_b[6]=2; v8_b[7]=1;
        pack_int8;
        precision = 2'b10;
        acc_in = 32'sd10;
        check_result(120, 130);

        // ------------------------------------------------------------
        // TEST 2: INT8 signed values
        // ------------------------------------------------------------
        ref_sum = 0;
        for (i = 0; i < 8; i = i + 1) begin
            v8_a[i] = i - 4;
            v8_b[i] = 3 - i;
            ref_sum = ref_sum + (v8_a[i] * v8_b[i]);
        end
        pack_int8;
        precision = 2'b10;
        acc_in = -7;
        check_result(ref_sum, ref_sum - 7);

        // ------------------------------------------------------------
        // TEST 3: INT4 pattern
        // values kept inside signed INT4 range [-8,7]
        // ------------------------------------------------------------
        ref_sum = 0;
        for (i = 0; i < 16; i = i + 1) begin
            v4_a[i] = (i % 8) - 4;
            v4_b[i] = 3 - (i % 8);
            ref_sum = ref_sum + (v4_a[i] * v4_b[i]);
        end
        pack_int4;
        precision = 2'b01;
        acc_in = 25;
        check_result(ref_sum, ref_sum + 25);

        // ------------------------------------------------------------
        // TEST 4: INT2 pattern
        // signed INT2 range is [-2, 1]
        // ------------------------------------------------------------
        ref_sum = 0;
        for (i = 0; i < 32; i = i + 1) begin
            case (i % 4)
                0: v2_a[i] = -2;
                1: v2_a[i] = -1;
                2: v2_a[i] =  0;
                default: v2_a[i] = 1;
            endcase
            case ((i+1) % 4)
                0: v2_b[i] = -2;
                1: v2_b[i] = -1;
                2: v2_b[i] =  0;
                default: v2_b[i] = 1;
            endcase
            ref_sum = ref_sum + (v2_a[i] * v2_b[i]);
        end
        pack_int2;
        precision = 2'b00;
        acc_in = -10;
        check_result(ref_sum, ref_sum - 10);

        // ------------------------------------------------------------
        // TEST 5: Max positive-ish INT8 dot
        // 8 x (127*127) = 129032
        // ------------------------------------------------------------
        ref_sum = 0;
        for (i = 0; i < 8; i = i + 1) begin
            v8_a[i] = 127;
            v8_b[i] = 127;
            ref_sum = ref_sum + (v8_a[i] * v8_b[i]);
        end
        pack_int8;
        precision = 2'b10;
        acc_in = 0;
        check_result(ref_sum, ref_sum);

        // ------------------------------------------------------------
        // TEST 6: unsupported precision -> zero dot
        // ------------------------------------------------------------
        a = 64'hFFFF_FFFF_FFFF_FFFF;
        b = 64'hFFFF_FFFF_FFFF_FFFF;
        precision = 2'b11;
        acc_in = 123;
        check_result(0, 123);

        if (errors == 0)
            $display("\nALL TESTS PASSED\n");
        else
            $display("\nTESTS FAILED: %0d error(s)\n", errors);

        #5;
        $finish;
    end
endmodule
