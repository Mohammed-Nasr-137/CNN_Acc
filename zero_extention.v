module zero_extention #(
    parameter PIXEL_IN_WIDTH  = 8,
    parameter PIXEL_OUT_WIDTH = PIXEL_IN_WIDTH + 1,
    parameter KERNEL_SIZE     = 3
)(
    input  wire        [(PIXEL_IN_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0] pixel_in,
    output wire signed [(PIXEL_OUT_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0] pixel_out
);

    genvar i;

    localparam NUM_REG = KERNEL_SIZE * KERNEL_SIZE;

    generate

        for (i = 0; i < NUM_REG; i = i + 1) begin

            assign pixel_out[(i * PIXEL_OUT_WIDTH) +: PIXEL_OUT_WIDTH] =
                {{(PIXEL_OUT_WIDTH - PIXEL_IN_WIDTH){1'b0}},
                 pixel_in[(i * PIXEL_IN_WIDTH) +: PIXEL_IN_WIDTH]};

        end

    endgenerate

endmodule