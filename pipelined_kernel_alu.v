// ============================================================
// TOP LEVEL
//
// KERNEL_SIZE = 3:
//     9 -> 3 -> 1
//
// KERNEL_SIZE = 5:
//     25 -> 9 -> 3 -> 1
//
// KERNEL_SIZE = 7:
//     49 -> 17 -> 6 -> 2 -> 1
// ============================================================

module pipelined_kernel_alu #(
    parameter DATA_WIDTH  = 16,
    parameter KERNEL_SIZE = 3,
    parameter OUT_WIDTH     = 16,
    parameter FRAC_BITS     = 0,
    parameter ENABLE_ROUND  = 0,
    parameter ENABLE_RELU   = 0
)(
    input wire clk,
    input wire rst,
    input wire valid_in,

    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] kernel_data,

    output wire [OUT_WIDTH-1:0] result,

    output wire valid_out
);


    localparam TOTAL_INPUTS = KERNEL_SIZE * KERNEL_SIZE;


    // ========================================================
    // Reduction pipeline
    // ========================================================

    reduction_pipeline #(
    .DATA_WIDTH   (DATA_WIDTH),
    .IN_COUNT     (TOTAL_INPUTS),
    .OUT_WIDTH    (OUT_WIDTH),
    .FRAC_BITS    (FRAC_BITS),
    .ENABLE_ROUND (ENABLE_ROUND),
    .ENABLE_RELU  (ENABLE_RELU)
) u_reduction_pipeline (

        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),

        .data_in   (kernel_data),

        .result    (result),
        .valid_out (valid_out)

    );

endmodule