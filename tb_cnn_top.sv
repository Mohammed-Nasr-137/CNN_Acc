`timescale 1ns / 1ps

module tb_cnn_top;

    // -------------------------------------------------------------------------
    // Parameters (Configured for linear convolution test)
    // -------------------------------------------------------------------------
    localparam INPUT_ROWS   = 32;
    localparam INPUT_COLUMN = 32;
    localparam PIXEL_SIZE   = 8;
    localparam KERNEL_SIZE  = 3;
    localparam WEIGHT_SIZE  = 8;
    localparam RELU         = 0; // Linear mode: preserves signed gradient outputs
    localparam PRODUCT_SIZE = 17;
    localparam OUTPUT_SIZE  = 16;
    localparam LINE_DEPTH   = 32;
    localparam FRAC_BITS    = 0; // Raw integer accumulation (no fractional shift)
    localparam ENABLE_ROUND = 0;

    localparam TOTAL_PIXELS  = INPUT_ROWS * INPUT_COLUMN;
    localparam OUT_ROWS      = INPUT_ROWS - KERNEL_SIZE + 1;
    localparam OUT_COLS      = INPUT_COLUMN - KERNEL_SIZE + 1;
    localparam TOTAL_EXPECTED = OUT_ROWS * OUT_COLS; // 30 x 30 = 900 outputs

    // -------------------------------------------------------------------------
    // Clock & Interface Signals
    // -------------------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg  [PIXEL_SIZE-1:0]  pixel_in;
    reg                    valid_in;
    reg  [WEIGHT_SIZE-1:0] weight_in;
    reg                    load_w;
    wire [OUTPUT_SIZE-1:0] pixel_out;
    wire                   valid_out;

    // -------------------------------------------------------------------------
    // Verification Data Structures
    // -------------------------------------------------------------------------
    reg  [PIXEL_SIZE-1:0]       test_image [0:INPUT_ROWS-1][0:INPUT_COLUMN-1];
    reg  signed [WEIGHT_SIZE-1:0] test_kernel [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
    
    // Golden reference FIFO queue
    reg signed [OUTPUT_SIZE-1:0] expected_queue [$];

    integer match_count = 0;
    integer mismatch_count = 0;
    integer out_pixel_idx = 0;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    cnn_top #(
        .INPUT_ROWS  (INPUT_ROWS),
        .INPUT_COLUMN(INPUT_COLUMN),
        .PIXEL_SIZE  (PIXEL_SIZE),
        .KERNEL_SIZE (KERNEL_SIZE),
        .WEIGHT_SIZE (WEIGHT_SIZE),
        .RELU        (RELU),
        .PRODUCT_SIZE(PRODUCT_SIZE),
        .OUTPUT_SIZE (OUTPUT_SIZE),
        .LINE_DEPTH  (LINE_DEPTH),
        .FRAC_BITS   (FRAC_BITS),
        .ENABLE_ROUND(ENABLE_ROUND)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_in   (pixel_in),
        .valid_in   (valid_in),
        .weight_in  (weight_in),
        .load_w     (load_w),
        .pixel_out  (pixel_out),
        .valid_out  (valid_out)
    );

    // -------------------------------------------------------------------------
    // Clock Generator (100 MHz)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Golden Model Reference Calculation
    // -------------------------------------------------------------------------
    function void generate_golden_reference();
        integer r, c, kr, kc;
        reg signed [31:0] sum;
        reg signed [OUTPUT_SIZE-1:0] saturated_val;
        
        for (r = 0; r < OUT_ROWS; r = r + 1) begin
            for (c = 0; c < OUT_COLS; c = c + 1) begin
                sum = 0;
                // Spatial window dot-product
                for (kr = 0; kr < KERNEL_SIZE; kr = kr + 1) begin
                    for (kc = 0; kc < KERNEL_SIZE; kc = kc + 1) begin
                        sum = sum + ($signed({1'b0, test_image[r + kr][c + kc]}) * 
                                     $signed(test_kernel[kr][kc]));
                    end
                end

                // Symmetric Saturation to signed 16-bit container
                if (sum > 32767)
                    saturated_val = 16'sh7FFF;
                else if (sum < -32768)
                    saturated_val = -16'sh8000;
                else
                    saturated_val = sum[OUTPUT_SIZE-1:0];

                expected_queue.push_back(saturated_val);
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Main Stimulus Task
    // -------------------------------------------------------------------------
    initial begin
        integer r, c, i;

        // 1. Initialize Inputs
        rst_n    = 1'b0;
        pixel_in = '0;
        valid_in = 1'b0;
        weight_in = '0;
        load_w   = 1'b0;

        // 2. Define Test Kernel (Sobel-X Vertical Edge Detector)
        test_kernel[0][0] = -8'sd1; test_kernel[0][1] =  8'sd0; test_kernel[0][2] =  8'sd1;
        test_kernel[1][0] = -8'sd2; test_kernel[1][1] =  8'sd0; test_kernel[1][2] =  8'sd2;
        test_kernel[2][0] = -8'sd1; test_kernel[2][1] =  8'sd0; test_kernel[2][2] =  8'sd1;

        // 3. Define Input Image (Horizontal Gradient Ramp)
        for (r = 0; r < INPUT_ROWS; r = r + 1) begin
            for (c = 0; c < INPUT_COLUMN; c = c + 1) begin
                test_image[r][c] = ((c * 8) + r) % 256;
            end
        end

        // 4. Compute Expected Queue
        generate_golden_reference();
        $display("[TB] Golden Reference Generated. Total Expected Pixels = %0d", expected_queue.size());

        // 5. Reset DUT
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // 6. Load Weights into Kernel Register File (9 Clock Cycles)
        $display("[TB] Loading Kernel Weights...");
        for (r = 0; r < KERNEL_SIZE; r = r + 1) begin
            for (c = 0; c < KERNEL_SIZE; c = c + 1) begin
                @(posedge clk);
                load_w    <= 1'b1;
                weight_in <= test_kernel[r][c];
            end
        end
        @(posedge clk);
        load_w    <= 1'b0;
        weight_in <= '0;

        // 7. Stream Image Pixels (Inject a 3-cycle stall midway to verify stall resilience)
        $display("[TB] Streaming Image Pixels into Accelerator...");
        for (r = 0; r < INPUT_ROWS; r = r + 1) begin
            for (c = 0; c < INPUT_COLUMN; c = c + 1) begin
                @(posedge clk);
                valid_in <= 1'b1;
                pixel_in <= test_image[r][c];

                // Inject upstream bubble test at pixel (10, 10)
                if (r == 10 && c == 10) begin
                    @(posedge clk);
                    valid_in <= 1'b0;
                    pixel_in <= '0;
                    repeat (3) @(posedge clk);
                end
            end
        end

        @(posedge clk);
        valid_in <= 1'b0;
        pixel_in <= '0;

        // 8. Wait for pipeline drain
        wait (expected_queue.size() == 0 || mismatch_count > 0);
        repeat (10) @(posedge clk);

        // 9. Simulation Verdict
        $display("=================================================");
        $display("                 SIMULATION REPORT               ");
        $display("=================================================");
        $display("  Total Matches   : %0d / %0d", match_count, TOTAL_EXPECTED);
        $display("  Total Mismatches: %0d", mismatch_count);
        $display("=================================================");

        if (mismatch_count == 0 && match_count == TOTAL_EXPECTED) begin
            $display("[TB] >>> TEST PASSED: ALL OUTPUTS MATCH GOLDEN MODEL BIT-ACCURATELY! <<<");
        end else begin
            $display("[TB] >>> TEST FAILED: DISCREPANCIES DETECTED! <<<");
        end

        $finish;
    end

    // -------------------------------------------------------------------------
    // Self-Checking Monitor Process
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            reg signed [OUTPUT_SIZE-1:0] expected_val;

            if (expected_queue.size() == 0) begin
                $error("[TB ERROR] Unexpected valid_out pulse when expected queue is empty at time %0t!", $time);
                mismatch_count = mismatch_count + 1;
            end else begin
                expected_val = expected_queue.pop_front();
                
                if ($signed(pixel_out) === expected_val) begin
                    match_count = match_count + 1;
                end else begin
                    $error("[TB MISMATCH] Pixel #%0d | Expected: %0d (0x%04h) | Got: %0d (0x%04h) at time %0t",
                           out_pixel_idx, expected_val, expected_val, $signed(pixel_out), pixel_out, $time);
                    mismatch_count = mismatch_count + 1;
                end
                out_pixel_idx = out_pixel_idx + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Watchdog Timer (Prevents infinite hang if valid_out fails to assert)
    // -------------------------------------------------------------------------
    initial begin
        #50000; // 50 microseconds
        if (match_count < TOTAL_EXPECTED) begin
            $display("\n[TB FATAL] Watchdog timeout reached! Simulation hung or valid_out stopped pulsing.");
            $display("  Processed: %0d / %0d outputs.", match_count, TOTAL_EXPECTED);
            $finish;
        end
    end

endmodule