module window_reg #(
    parameter PIXEL_WIDTH  = 8,
    parameter KERNEL_SIZE  = 3
)(
    input  wire rst_n,
    input  wire clk,
    input  wire valid_in,

    input wire [(PIXEL_WIDTH * KERNEL_SIZE)-1:0] row_pixel, // packed input pixels

    output wire [(PIXEL_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0] window_out // packed output window

    // output reg valid_out
);

reg [PIXEL_WIDTH-1:0] win_reg [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];

genvar i, j;
integer r, c;


// -----------------------------------------------------------
// Window register logic
// -----------------------------------------------------------

always @(posedge clk) begin

    if (!rst_n) begin

        for (r = 0; r < KERNEL_SIZE; r = r + 1) begin

            for (c = 0; c < KERNEL_SIZE; c = c + 1) begin
                win_reg[r][c] <= {PIXEL_WIDTH{1'b0}};
            end

        end

    end

    else if (valid_in) begin

        for (r = 0; r < KERNEL_SIZE; r = r + 1) begin

            for (c = 0; c < KERNEL_SIZE-1; c = c + 1) begin
                win_reg[r][c] <= win_reg[r][c+1];
            end

            // Shift register to the left
            // Input to the window
            win_reg[r][KERNEL_SIZE-1] <=
                row_pixel[(r * PIXEL_WIDTH) +: PIXEL_WIDTH];

        end

    end

end


// -----------------------------------------------------------
// Connecting 2D window register to 1D output
// -----------------------------------------------------------

generate

    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin : row_counter

        for (j = 0; j < KERNEL_SIZE; j = j + 1) begin : col_counter

            assign window_out[
                ((KERNEL_SIZE * i + j) * PIXEL_WIDTH) +: PIXEL_WIDTH
            ] = win_reg[i][j];

        end

    end

endgenerate

endmodule