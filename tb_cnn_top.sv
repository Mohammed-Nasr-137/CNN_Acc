`timescale 1ns / 1ps

module tb_cnn_top;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam NUM_KERNELS  = 2;
    localparam INPUT_ROWS   = 32;
    localparam INPUT_COLUMN = 32;
    localparam PIXEL_SIZE   = 8;
    localparam KERNEL_SIZE  = 3;
    localparam WEIGHT_SIZE  = 8;
    localparam RELU         = 0; // Linear mode to preserve signed Sobel gradients
    localparam PRODUCT_SIZE = 17;
    localparam OUTPUT_SIZE  = 16;
    localparam LINE_DEPTH   = 32;
    localparam FRAC_BITS    = 0; 
    localparam ENABLE_ROUND = 0;

    localparam TOTAL_PIXELS   = INPUT_ROWS * INPUT_COLUMN;
    localparam OUT_ROWS       = INPUT_ROWS - KERNEL_SIZE + 1;
    localparam OUT_COLS       = INPUT_COLUMN - KERNEL_SIZE + 1;
    localparam TOTAL_EXPECTED = OUT_ROWS * OUT_COLS; // 900 outputs

    // -------------------------------------------------------------------------
    // Clock & Interface Signals
    // -------------------------------------------------------------------------
    reg                                      clk;
    reg                                      rst_n;
    reg  [PIXEL_SIZE-1:0]                    pixel_in;
    reg                                      valid_in;
    reg  [(NUM_KERNELS*WEIGHT_SIZE)-1:0]     weight_in;
    reg                                      load_w;
    wire [(NUM_KERNELS*OUTPUT_SIZE)-1:0]     pixel_out;
    wire                                     valid_out; // Reduced to 1-bit

    // -------------------------------------------------------------------------
    // Verification Data Structures
    // -------------------------------------------------------------------------
    reg  [PIXEL_SIZE-1:0]       test_image [0:INPUT_ROWS-1][0:INPUT_COLUMN-1];
    reg  signed [WEIGHT_SIZE-1:0] test_kernel_0 [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1]; // Sobel-X
    reg  signed [WEIGHT_SIZE-1:0] test_kernel_1 [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1]; // Sobel-Y
    
    // Golden reference FIFO queue (WIDENED to 32 bits to hold both kernel results)
    reg [(NUM_KERNELS*OUTPUT_SIZE)-1:0] expected_queue [$];

    integer match_count = 0;
    integer mismatch_count = 0;
    integer out_pixel_idx = 0;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    cnn_top #(
        .NUM_KERNELS (NUM_KERNELS),
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
    // Clock & Power Profiling Generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Golden Model Reference Calculation (Dual-Core)
    // -------------------------------------------------------------------------
    function void generate_golden_reference();
        integer r, c, kr, kc;
        reg signed [31:0] sum_0, sum_1;
        reg signed [OUTPUT_SIZE-1:0] sat_0, sat_1;
        reg [(NUM_KERNELS*OUTPUT_SIZE)-1:0] packed_expected;
        
        for (r = 0; r < OUT_ROWS; r = r + 1) begin
            for (c = 0; c < OUT_COLS; c = c + 1) begin
                sum_0 = 0;
                sum_1 = 0;
                
                // Spatial window dot-product for BOTH kernels
                for (kr = 0; kr < KERNEL_SIZE; kr = kr + 1) begin
                    for (kc = 0; kc < KERNEL_SIZE; kc = kc + 1) begin
                        sum_0 = sum_0 + ($signed({1'b0, test_image[r + kr][c + kc]}) * $signed(test_kernel_0[kr][kc]));
                        sum_1 = sum_1 + ($signed({1'b0, test_image[r + kr][c + kc]}) * $signed(test_kernel_1[kr][kc]));
                    end
                end

                // Symmetric Saturation Core 0
                if (sum_0 > 32767)       sat_0 = 16'sh7FFF;
                else if (sum_0 < -32768) sat_0 = -16'sh8000;
                else                     sat_0 = sum_0[OUTPUT_SIZE-1:0];

                // Symmetric Saturation Core 1
                if (sum_1 > 32767)       sat_1 = 16'sh7FFF;
                else if (sum_1 < -32768) sat_1 = -16'sh8000;
                else                     sat_1 = sum_1[OUTPUT_SIZE-1:0];

                // Pack expected values: Core 1 occupies MSBs, Core 0 occupies LSBs
                packed_expected = {sat_1, sat_0};
                expected_queue.push_back(packed_expected);
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Main Stimulus Task
    // -------------------------------------------------------------------------
    initial begin
        integer r, c, i;

        rst_n     = 1'b0;
        pixel_in  = '0;
        valid_in  = 1'b0;
        weight_in = '0;
        load_w    = 1'b0;

        // Core 0: Sobel-X (Vertical Edge)
        test_kernel_0[0][0] = -8'sd1; test_kernel_0[0][1] =  8'sd0; test_kernel_0[0][2] =  8'sd1;
        test_kernel_0[1][0] = -8'sd2; test_kernel_0[1][1] =  8'sd0; test_kernel_0[1][2] =  8'sd2;
        test_kernel_0[2][0] = -8'sd1; test_kernel_0[2][1] =  8'sd0; test_kernel_0[2][2] =  8'sd1;

        // Core 1: Sobel-Y (Horizontal Edge)
        test_kernel_1[0][0] =  8'sd1; test_kernel_1[0][1] =  8'sd2; test_kernel_1[0][2] =  8'sd1;
        test_kernel_1[1][0] =  8'sd0; test_kernel_1[1][1] =  8'sd0; test_kernel_1[1][2] =  8'sd0;
        test_kernel_1[2][0] = -8'sd1; test_kernel_1[2][1] = -8'sd2; test_kernel_1[2][2] = -8'sd1;

        // Define Input Image (Gradient Ramp)
        for (r = 0; r < INPUT_ROWS; r = r + 1) begin
            for (c = 0; c < INPUT_COLUMN; c = c + 1) begin
                test_image[r][c] = ((c * 8) + r) % 256;
            end
        end

        // Compute Dual-Core Expected Queue
        generate_golden_reference();
        $display("[TB] Golden Reference Generated. Expected %0d Dual-Core Pixels.", expected_queue.size());

        // Reset DUT
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Load BOTH Kernels in Parallel (Concatenated Bus)
        $display("[TB] Loading Dual Kernel Weights...");
        for (r = 0; r < KERNEL_SIZE; r = r + 1) begin
            for (c = 0; c < KERNEL_SIZE; c = c + 1) begin
                @(posedge clk);
                load_w    <= 1'b1;
                // Core 1 weights go to MSBs, Core 0 weights go to LSBs
                weight_in <= {test_kernel_1[r][c], test_kernel_0[r][c]};
            end
        end
        @(posedge clk);
        load_w    <= 1'b0;
        weight_in <= '0;

        // Stream Image Pixels (With 3-cycle stall midway)
        $display("[TB] Streaming Image Pixels into Accelerator...");
        for (r = 0; r < INPUT_ROWS; r = r + 1) begin
            for (c = 0; c < INPUT_COLUMN; c = c + 1) begin
                @(posedge clk);
                valid_in <= 1'b1;
                pixel_in <= test_image[r][c];

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

        // Wait for pipeline drain
        wait (expected_queue.size() == 0 || mismatch_count > 0);
        repeat (10) @(posedge clk);

        // Close SAIF logging before termination
        $close_saif();

        // Simulation Verdict
        $display("=================================================");
        $display("                 SIMULATION REPORT               ");
        $display("=================================================");
        $display("  Total Matches   : %0d / %0d", match_count, TOTAL_EXPECTED);
        $display("  Total Mismatches: %0d", mismatch_count);
        $display("=================================================");

        if (mismatch_count == 0 && match_count == TOTAL_EXPECTED) begin
            $display("[TB] >>> TEST PASSED: ALL 32-BIT OUTPUTS MATCH GOLDEN MODEL BITS! <<<");
        end else begin
            $display("[TB] >>> TEST FAILED: DISCREPANCIES DETECTED! <<<");
        end

        $finish;
    end

    // -------------------------------------------------------------------------
    // Self-Checking Monitor Process (Checks full 32-bit concatenated word)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            reg [(NUM_KERNELS*OUTPUT_SIZE)-1:0] expected_val;

            if (expected_queue.size() == 0) begin
                $error("[TB ERROR] Unexpected valid_out pulse when expected queue is empty at time %0t!", $time);
                mismatch_count = mismatch_count + 1;
            end else begin
                expected_val = expected_queue.pop_front();
                
                // Absolute bit-accurate check across the entire 32-bit bus
                if (pixel_out === expected_val) begin
                    match_count = match_count + 1;
                end else begin
                    $error("[TB MISMATCH] Pixel #%0d | Expected: 0x%08h | Got: 0x%08h at time %0t",
                           out_pixel_idx, expected_val, pixel_out, $time);
                    mismatch_count = mismatch_count + 1;
                end
                out_pixel_idx = out_pixel_idx + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Watchdog Timer
    // -------------------------------------------------------------------------
    initial begin
        #50000;
        if (match_count < TOTAL_EXPECTED) begin
            $display("\n[TB FATAL] Watchdog timeout reached! Simulation hung or valid_out stopped pulsing.");
            $display("  Processed: %0d / %0d outputs.", match_count, TOTAL_EXPECTED);
            $finish;
        end
    end

endmodule