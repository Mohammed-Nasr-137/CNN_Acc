`timescale 1ns/1ps

// ================================================================
// SELF-CHECKING TESTBENCH for pipelined_kernel_alu
//
// DUT hierarchy exercised:
//   pipelined_kernel_alu
//     -> reduction_pipeline (recursive)
//          -> pipeline_stage
//               -> add3 / add2
//
// Reference model:
//   With the default parameters that reduction_pipeline uses when
//   it instantiates pipeline_stage (OUT_WIDTH=16, FRAC_BITS=0,
//   ENABLE_ROUND=1, ENABLE_RELU=0), FRAC_BITS=0 makes the rounding
//   and shift stages no-ops. So intended behavior reduces to:
//       result = saturate_to_signed(DATA_WIDTH, sum(all inputs))
//
// NOTE FOR DEBUG:
//   reduction_pipeline instantiates pipeline_stage as:
//       pipeline_stage #(.DATA_WIDTH(DATA_WIDTH), .IN_COUNT(IN_COUNT))
//   but pipeline_stage's actual width parameter is named IN_WIDTH,
//   not DATA_WIDTH. Most simulators will flag/ignore the unknown
//   parameter override and silently fall back to IN_WIDTH's default
//   (16), so the width growth (+2 bits/stage) that reduction_pipeline
//   *intends* to pass down the recursion never actually happens.
//   If you see mismatches only for KERNEL_SIZE >= 5 (i.e. more than
//   one reduction level), or only on large-magnitude random vectors,
//   this parameter name mismatch is the first place to look.
// ================================================================

module tb_pipelined_kernel_alu;

    // ------------------------------------------------------------
    // Parameters - change KERNEL_SIZE here to retarget 3/5/7 etc.
    // ------------------------------------------------------------
    parameter int DATA_WIDTH     = 16;
    parameter int KERNEL_SIZE    = 7;
    parameter int TOTAL_INPUTS   = KERNEL_SIZE * KERNEL_SIZE;

    parameter time CLK_PERIOD    = 10ns;
    parameter int  NUM_RANDOM_TESTS = 200;

    localparam longint signed MAX_VAL =  (64'sh1 <<< (DATA_WIDTH-1)) - 1;
    localparam longint signed MIN_VAL = -(64'sh1 <<< (DATA_WIDTH-1));
    //localparam longint signed MIN_VAL = 0 ;

    // Pipeline latency = number of reduction_pipeline register
    // stages traversed until IN_COUNT collapses to 1.
    function automatic int calc_latency(int in_count);
        int count;
        int lat;
        count = in_count;
        lat   = 0;
        while (count > 1) begin
            count = (count + 2) / 3;
            lat   = lat + 1;
        end
        return lat;
    endfunction

    localparam int LATENCY = calc_latency(TOTAL_INPUTS);

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic clk;
    logic rst;                     // active-low
    logic valid_in;
    logic [TOTAL_INPUTS*DATA_WIDTH-1:0] kernel_data;

    logic [DATA_WIDTH-1:0] result;
    logic                  valid_out;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    pipelined_kernel_alu #(
        .DATA_WIDTH (DATA_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .valid_in   (valid_in),
        .kernel_data(kernel_data),
        .result     (result),
        .valid_out  (valid_out)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------
    // Scoreboard (two parallel queues instead of a struct queue,
    // for broad simulator compatibility)
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] exp_val_q[$];
    int                           exp_tag_q[$];

    int test_num   = 0;
    int pass_count = 0;
    int fail_count = 0;

    // ------------------------------------------------------------
    // Golden reference model
    // ------------------------------------------------------------
    function automatic logic signed [DATA_WIDTH-1:0] golden_model(
        input logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS]
    );
        longint signed sum;
        sum = 0;
        for (int i = 0; i < TOTAL_INPUTS; i++)
            sum += vals[i];

        if (sum > MAX_VAL)
            return MAX_VAL[DATA_WIDTH-1:0];
        else if (sum < MIN_VAL)
            return MIN_VAL[DATA_WIDTH-1:0];
        else
            return sum[DATA_WIDTH-1:0];
    endfunction

    // ------------------------------------------------------------
    // Drive one kernel, queue expected result, hold valid_in 1 cyc
    // ------------------------------------------------------------
    task automatic drive_kernel(input logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS]);
        for (int i = 0; i < TOTAL_INPUTS; i++)
            kernel_data[i*DATA_WIDTH +: DATA_WIDTH] = vals[i];

        valid_in = 1'b1;
        exp_val_q.push_back(golden_model(vals));
        exp_tag_q.push_back(test_num);
        test_num++;

        @(posedge clk);
        valid_in = 1'b0;
    endtask

    // ------------------------------------------------------------
    // Checker
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] chk_expected;
    int                           chk_tag;

    always @(posedge clk) begin
        if (rst && valid_out) begin
            if (exp_val_q.size() == 0) begin
                $display("[%0t] ERROR: valid_out asserted with empty expected queue", $time);
                fail_count++;
            end else begin
                chk_expected = exp_val_q.pop_front();
                chk_tag      = exp_tag_q.pop_front();
                if (result === chk_expected) begin
                    $display("[%0t] PASS  test#%0d  result=%0d expected=%0d",
                              $time, chk_tag, $signed(result), chk_expected);
                    pass_count++;
                end else begin
                    $display("[%0t] FAIL  test#%0d  result=%0d expected=%0d",
                              $time, chk_tag, $signed(result), chk_expected);
                    fail_count++;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Reset (active-low)
    // ------------------------------------------------------------
    task automatic do_reset();
        rst         = 1'b0;
        valid_in    = 1'b0;
        kernel_data = '0;
        repeat (3) @(posedge clk);
        rst = 1'b1;
        @(posedge clk);
    endtask

    // ------------------------------------------------------------
    // Directed tests
    // ------------------------------------------------------------
    task automatic run_directed_tests();
        logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS];

        // all zeros
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = 0;
        drive_kernel(vals);

        // all ones
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = 1;
        drive_kernel(vals);

        // incrementing ramp
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = i;
        drive_kernel(vals);

        // alternating max-pos / zero
        for (int i = 0; i < TOTAL_INPUTS; i++)
            vals[i] = (i % 2 == 0) ? 16'sh7FFF : 16'sh0000;
        drive_kernel(vals);

        // all max positive -> forces positive saturation
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = 16'sh7FFF;
        drive_kernel(vals);

        // all min negative -> forces negative saturation
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = 16'sh8000;
        drive_kernel(vals);

        // sums to exactly zero
        for (int i = 0; i < TOTAL_INPUTS; i++)
            vals[i] = (i % 2 == 0) ? 16'sd100 : -16'sd100;
        drive_kernel(vals);
    endtask

    // ------------------------------------------------------------
    // Random tests (one idle cycle between transactions)
    // ------------------------------------------------------------
    task automatic run_random_tests(int n);
        logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS];
        for (int t = 0; t < n; t++) begin
            for (int i = 0; i < TOTAL_INPUTS; i++)
                vals[i] = $random;
            drive_kernel(vals);
        end
    endtask

    // ------------------------------------------------------------
    // Back-to-back valid_in stress test (no bubbles)
    // ------------------------------------------------------------
    task automatic run_back_to_back(int n);
        logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS];
        for (int t = 0; t < n; t++) begin
            for (int i = 0; i < TOTAL_INPUTS; i++)
                vals[i] = $random;

            for (int i = 0; i < TOTAL_INPUTS; i++)
                kernel_data[i*DATA_WIDTH +: DATA_WIDTH] = vals[i];

            valid_in = 1'b1;
            exp_val_q.push_back(golden_model(vals));
            exp_tag_q.push_back(test_num);
            test_num++;

            @(posedge clk);
        end
        valid_in = 1'b0;
    endtask

    // ------------------------------------------------------------
    // Mid-stream reset test - flush pipeline, drop stale results
    // ------------------------------------------------------------
    task automatic run_reset_test();
        logic signed [DATA_WIDTH-1:0] vals[TOTAL_INPUTS];
        for (int i = 0; i < TOTAL_INPUTS; i++) vals[i] = 500 + i;

        for (int i = 0; i < TOTAL_INPUTS; i++)
            kernel_data[i*DATA_WIDTH +: DATA_WIDTH] = vals[i];

        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // assert reset mid-flight, before the result emerges
        rst = 1'b0;
        @(posedge clk);
        rst = 1'b1;

        // pipeline was flushed - drop in-flight expectations
        exp_val_q.delete();
        exp_tag_q.delete();

        repeat (2) @(posedge clk);
    endtask

    // ------------------------------------------------------------
    // Main
    // ------------------------------------------------------------
    initial begin
        do_reset();

        run_directed_tests();
        run_random_tests(NUM_RANDOM_TESTS);
        run_back_to_back(20);
        run_reset_test();
        run_directed_tests();

        // drain any results still in flight
        repeat (LATENCY + 5) @(posedge clk);

        $display("=====================================================");
        $display(" KERNEL_SIZE : %0d (TOTAL_INPUTS=%0d)", KERNEL_SIZE, TOTAL_INPUTS);
        $display(" LATENCY     : %0d cycles", LATENCY);
        $display(" TESTS RUN   : %0d", test_num);
        $display(" PASS        : %0d", pass_count);
        $display(" FAIL        : %0d", fail_count);
        $display(" UNMATCHED   : %0d (results never seen)", exp_val_q.size());
        $display("=====================================================");

        if (fail_count == 0 && exp_val_q.size() == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: FAILURES DETECTED");

        $stop;
    end

    // Safety timeout
    initial begin
        #(CLK_PERIOD * 20000);
        $display("ERROR: TIMEOUT - simulation did not finish");
        $stop;
    end

endmodule