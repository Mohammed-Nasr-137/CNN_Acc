// ============================================================
// PARAMETERIZED PIPELINED 3-INPUT ADDER TREE
//
// KERNEL_SIZE = 3:
//     9 -> 3 -> 1
//
// KERNEL_SIZE = 5:
//     25 -> 9 -> 3 -> 1
//
// KERNEL_SIZE = 7:
//     49 -> 17 -> 6 -> 2 -> 1
//
// Every reduction stage is pipelined.
// ============================================================

module reduction_pipeline #(
    parameter DATA_WIDTH = 16,
    parameter IN_COUNT   = 1,

    parameter OUT_WIDTH     = 16,
    parameter FRAC_BITS     = 4,
    parameter ENABLE_ROUND  = 1,
    parameter ENABLE_RELU   = 1
)(
    input wire clk,
    input wire rst,
    input wire valid_in,

    input wire  [IN_COUNT*DATA_WIDTH-1:0] data_in,

    output wire [ OUT_WIDTH-1:0] result,

    output wire valid_out
);

    localparam OUT_COUNT = (IN_COUNT == 2) ? 1 : (IN_COUNT/3) + (IN_COUNT%3);

    // ========================================================
    // BASE CASE
    //
    // Only one value remains.
    //
    // IMPORTANT:
    // result and valid_out are wires because they are driven
    // by the final register module below.
    // ========================================================

    generate

        if (IN_COUNT == 1) begin : GEN_FINAL
            assign result    = data_in;
            assign valid_out = valid_in;
        end


        // ====================================================
        // RECURSIVE CASE
        // ====================================================

        else begin : GEN_STAGE


            // ------------------------------------------------
            // Output width of current reduction stage
            // ------------------------------------------------

            localparam STAGE_WIDTH = DATA_WIDTH + 2;


            // ------------------------------------------------
            // Number of values after this stage
            // ------------------------------------------------

            localparam STAGE_COUNT = OUT_COUNT;


            // ------------------------------------------------
            // Width of the data pipeline_stage actually drives
            // on data_out.
            //
            // When STAGE_COUNT == 1, this level's pipeline_stage
            // is itself the terminal reduction (its own
            // IN_COUNT is 2 or 3, i.e. its OUT_COUNT == 1), so it
            // has already performed rounding/shift/saturation/
            // ReLU and drives a single OUT_WIDTH-bit result -
            // NOT a STAGE_WIDTH-bit grown value.
            // ------------------------------------------------

            localparam CHILD_DATA_WIDTH =
                (STAGE_COUNT == 1) ? OUT_WIDTH : STAGE_WIDTH;

            // ------------------------------------------------
            // Current stage output
            // ------------------------------------------------

            wire [ (STAGE_COUNT*CHILD_DATA_WIDTH)-1:0  ] stage_data;

            wire stage_valid;


            // ------------------------------------------------
            // Current pipeline stage
            //
            // Example:
            //
            // 25 x 16-bit
            //       |
            //   8 ADD3
            //       |
            //       + leftover
            //       |
            //      9 x 18-bit
            //       |
            //    REGISTER
            // ------------------------------------------------

           pipeline_stage #(
    .IN_WIDTH     (DATA_WIDTH), 
    .IN_COUNT     (IN_COUNT),
    .OUT_WIDTH    (OUT_WIDTH),
    .FRAC_BITS    (FRAC_BITS),
    .ENABLE_ROUND (ENABLE_ROUND),
    .ENABLE_RELU  (ENABLE_RELU)
) u_pipeline_stage (

                .clk       (clk),
                .rst       (rst),
                .valid_in  (valid_in),

                .data_in   (data_in),

                .data_out  (stage_data),
                .valid_out (stage_valid)

            );


            // ------------------------------------------------
            // Recursive next stage
            //
            // 25 -> 9
            //  9 -> 3
            //  3 -> 1
            // ------------------------------------------------
            // OUT_WIDTH is the ultimate desired result width and
            // never changes across recursion levels - only the
            // per-element DATA_WIDTH of the *intermediate* data
            // grows (or, once finalized, locks to OUT_WIDTH).
            reduction_pipeline #(
                .DATA_WIDTH   (CHILD_DATA_WIDTH),
                .IN_COUNT     (STAGE_COUNT),

                .OUT_WIDTH    (OUT_WIDTH),
                .FRAC_BITS    (FRAC_BITS),
                .ENABLE_ROUND (ENABLE_ROUND),
                .ENABLE_RELU  (ENABLE_RELU)
            ) u_next_stage (

                .clk       (clk),
                .rst       (rst),
                .valid_in  (stage_valid),

                .data_in   (stage_data),

                .result    (result),
                .valid_out (valid_out)

            );



        end

    endgenerate

endmodule