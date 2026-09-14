module stage2_reg #(
    parameter OUT_WIDTH = 17,
    parameter KERNEL_SIZE = 3
) (
    input  wire                                                 clk,
    input  wire                                                 rst_n,
    input  wire                                                 valid_window,
    output reg                                                  valid_window_reg,
);
    
always @(posedge clk)
begin
    if (!rst_n)
    begin
        valid_window_reg <= 'b0;
    end
    else
    begin
        valid_window_reg <= valid_window;
    end
end

endmodule

