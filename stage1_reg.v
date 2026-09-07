module stage1_reg #(
    parameter PIXEL_SIZE  = 8,
    parameter KERNEL_SIZE = 3,
    parameter WEIGHT_SIZE = 8
) (
    input  wire                                                 clk,
    input  wire                                                 rst_n,
    input  wire                                                 valid_window,
    input  wire [(PIXEL_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0]  window_out_bus,
    input  wire [(WEIGHT_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0] krnl_out_bus,
    output reg                                                  valid_window_reg,
    output reg  [(PIXEL_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0]  window_out_bus_reg,
    output reg  [(WEIGHT_SIZE * KERNEL_SIZE * KERNEL_SIZE)-1:0] krnl_out_bus_reg
);
    
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        valid_window_reg   <= 'b0;
        window_out_bus_reg <= 'b0;
        krnl_out_bus_reg   <= 'b0;
    end
    else
    begin
        valid_window_reg   <= valid_window;
        if (valid_window)
        begin
            window_out_bus_reg <= window_out_bus;
            krnl_out_bus_reg   <= krnl_out_bus; 
        end
    end
end

endmodule
