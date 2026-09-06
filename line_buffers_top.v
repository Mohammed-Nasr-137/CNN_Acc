module line_buffers_top #(
    parameter LINE_DEPTH = 32,
    parameter N_LINES = 2,
    parameter PIXEL_SIZE   = 8
) (
    input  wire clk,
    input  wire enable,
    input  wire [PIXEL_SIZE-1:0] buffers_in,
    output wire [N_LINES*PIXEL_SIZE-1:0] buffers_out
);

wire [PIXEL_SIZE-1:0] buffers_carry [N_LINES:0];
assign buffers_carry[0] = buffers_in;
genvar i;

generate
    for (i = 0; i < N_LINES; i=i+1)
    begin
        line_buffer #(.DATA_WIDTH(PIXEL_SIZE), .LINE_DEPTH(LINE_DEPTH)) lf (
            .clk(clk),
            .enable(enable),
            .data_in(buffers_carry[i]),
            .data_out(buffers_carry[i+1])
        );
        assign buffers_out[i*PIXEL_SIZE +: PIXEL_SIZE] = buffers_carry[N_LINES-i];
    end
endgenerate
    
endmodule
