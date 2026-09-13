module cnn_top #(
    parameter INPUT_ROWS   = 32,              // number of rows of image or feature map
    parameter INPUT_COLUMN = 32,              // number of columns of image or feature map
    parameter PIXEL_SIZE   = 8,               // input precision
    parameter KERNEL_SIZE  = 3,               // N×N kernel
    parameter WEIGHT_SIZE  = 8,
    parameter NUM_KERNELS  = 1,               // number of supported kernels
    parameter RELU         = 1,               // 1=use ReLU, 0=don't use ReLU
    parameter PRODUCT_SIZE = 17,              // intermediate products size
    parameter OUTPUT_SIZE  = 16,
    parameter LINE_DEPTH   = 32,              // line buffer depth
    parameter FRAC_BITS    = 7,               // fractional bits to shift out
    parameter ENABLE_ROUND = 1                // 1=Round-half-up, 0=Truncate
) (
    input  wire                                 clk,
    input  wire                                 rst_n,
    input  wire [PIXEL_SIZE-1:0]                pixel_in,
    input  wire                                 valid_in,  // to indicate input pixel is valid
    input  wire [(NUM_KERNELS*WEIGHT_SIZE)-1:0] weight_in, // kernel weight
    input  wire                                 load_w,    // to enable loading weights
    output wire [(NUM_KERNELS*OUTPUT_SIZE)-1:0] pixel_out,
    output wire                                 valid_out
);

localparam N_LINES        = KERNEL_SIZE - 1;                 // number of line buffers
localparam PIXEL_SIZE_EXT = PIXEL_SIZE + 1;                  // pixel size after size extention
localparam OUT_WIDTH      = WEIGHT_SIZE + PIXEL_SIZE_EXT;    // width of the multipliers' outputs

// internal signals
// stage1
wire                                                enable;         // from ctrl to line buffers
wire [N_LINES*PIXEL_SIZE-1:0]                       buffers_taps;   // from line buffers to window registers
wire                                                valid_window;   // from ctrl to stage reg
wire [(PIXEL_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0] window_out_bus; // from window reg to stage reg

// fifo
wire [(NUM_KERNELS*OUTPUT_SIZE)-1:0]                fifo_pixel_in;  // from adder tree to fifo
wire [NUM_KERNELS-1:0]                              fifo_valid_in;  // from adder tree to fifo
wire                                                master_valid_out;

assign enable = valid_in;

line_buffers_top #(.LINE_DEPTH(LINE_DEPTH), .N_LINES(N_LINES), .PIXEL_SIZE(PIXEL_SIZE)) buffers (
    .clk(clk),
    .enable(enable),
    .buffers_in(pixel_in),
    .buffers_out(buffers_taps)
);

ctrl_unit #(.INPUT_ROWS(INPUT_ROWS), .INPUT_COLUMN(INPUT_COLUMN), .KERNEL_SIZE(KERNEL_SIZE)) ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .valid_out(valid_window)
);

window_reg #(.PIXEL_WIDTH(PIXEL_SIZE), .KERNEL_SIZE(KERNEL_SIZE)) win_regs (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .row_pixel({pixel_in, buffers_taps}),
    .window_out(window_out_bus)
);

genvar k;
generate
    for (k = 0; k < NUM_KERNELS; k = k + 1) begin : datapath

        // stage1
        wire [(WEIGHT_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0]    krnl_out_bus;        // from weights reg to multiplier
        wire [(PIXEL_SIZE_EXT * KERNEL_SIZE * KERNEL_SIZE)-1:0] pixels_extended;     // from sign extention to multipliers
        wire                                                    valid_mult_out;      // from multipliers to stage2 reg
        wire [(OUT_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0]      mult_out;            // from multipliers to stage2 reg

        // stage3
        wire                                                    valid_window_reg2;   // from stage reg2 to stage3 reg and adders tree enable
        wire [(OUT_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0]      mult_out_bus;        // from stage reg2 to adders tree

        kernel_weights #(.KERNEL_WIDTH(WEIGHT_SIZE), .KERNEL_SIZE(KERNEL_SIZE)) weights_regs (
            .clk(clk),
            .rst_n(rst_n),
            .krnl_in(weight_in[(k*WEIGHT_SIZE) +: WEIGHT_SIZE]),
            .krnl_enable(load_w),
            .krnl_out(krnl_out_bus)
        );
        zero_extention #(.PIXEL_IN_WIDTH(PIXEL_SIZE), .PIXEL_OUT_WIDTH(PIXEL_SIZE_EXT), .KERNEL_SIZE(KERNEL_SIZE)) zero_ext (
            .pixel_in(window_out_bus),
            .pixel_out(pixels_extended)
        );

        multiplier #(.KERNEL_WIDTH(WEIGHT_SIZE), .PIXEL_WIDTH_EXTN(PIXEL_SIZE_EXT), .OUT_WIDTH(OUT_WIDTH), .KERNEL_SIZE(KERNEL_SIZE)) multipliers (
            .clk(clk),
            .window(pixels_extended),
            .krnl(krnl_out_bus),
            .enable(valid_window),
            .mult_out(mult_out),
            .valid_out(valid_mult_out)
        );

        stage2_reg #(.OUT_WIDTH(OUT_WIDTH), .KERNEL_SIZE(KERNEL_SIZE)) stg2_reg (
            .clk(clk),
            .rst_n(rst_n),
            .valid_window(valid_window),
            .mult_out(mult_out),
            .valid_window_reg(valid_window_reg2),
            .mult_out_reg(mult_out_bus)
        );

        pipelined_kernel_alu #(.DATA_WIDTH(OUT_WIDTH), .KERNEL_SIZE(KERNEL_SIZE), .OUT_WIDTH(OUTPUT_SIZE), .FRAC_BITS(FRAC_BITS), .ENABLE_ROUND(ENABLE_ROUND), .ENABLE_RELU(RELU)) adder_tree (
            .clk(clk),
            .rst(rst_n), 
            .valid_in(valid_window_reg2),
            .kernel_data(mult_out_bus),
            .result(fifo_pixel_in[(k*OUTPUT_SIZE) +: OUTPUT_SIZE]),
            .valid_out(fifo_valid_in[k])
        );
    end
endgenerate

output_fifo #(.IMAGE_ROWS(INPUT_ROWS), .IMAGE_COLS(INPUT_COLUMN), .KERNEL_SIZE(KERNEL_SIZE), .OUTPUT_SIZE(NUM_KERNELS*OUTPUT_SIZE)) fifo (
            .clk(clk),
            .rst_n(rst_n),
            .adder_pixel_in(fifo_pixel_in),
            .adder_valid_in(fifo_valid_in[0]),
            .fifo_pixel_out(pixel_out),
            .fifo_valid_out(valid_out)
        );


endmodule
