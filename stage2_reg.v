module stage2_reg #(
    parameter OUT_WIDTH = 17,
    parameter KERNEL_SIZE = 3
) (
    input  wire                                                 clk,
    input  wire                                                 rst_n,
    input  wire                                                 valid_window,
    input  wire [(OUT_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0]   mult_out,
    output reg                                                  valid_window_reg,
    output reg  [(OUT_WIDTH * KERNEL_SIZE * KERNEL_SIZE)-1:0]   mult_out_reg
);
    
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        valid_window_reg <= 'b0;
        mult_out_reg     <= 'b0;
    end
    else
    begin
        valid_window_reg <= valid_window;
        if (valid_window)
        begin
            mult_out_reg <= mult_out;
        end
    end
end

endmodule

