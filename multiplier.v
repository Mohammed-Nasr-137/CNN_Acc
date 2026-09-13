module multiplier  #(parameter KERNEL_WIDTH     = 8,
                     parameter PIXEL_WIDTH_EXTN = 9,
                     parameter OUT_WIDTH        = KERNEL_WIDTH + PIXEL_WIDTH_EXTN,
                     parameter KERNEL_SIZE      = 3
                     

) ( 
    input wire                                                         clk,
    input wire signed [(PIXEL_WIDTH_EXTN*KERNEL_SIZE*KERNEL_SIZE)-1:0] window,
    input wire signed [(KERNEL_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] krnl,
    input wire  enable,

    output wire signed [(OUT_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] mult_out,
    output wire signed                                           valid_out
);

// wire valid ;

// assign valid = valid_krnl && valid_win;

genvar  k;

localparam KERNEL_FULL_SIZE = KERNEL_SIZE * KERNEL_SIZE;

always @(posedge clk) begin
    valid_out <= enable;
end

generate 
 for ( k = 0 ; k < KERNEL_FULL_SIZE ; k = k + 1) begin : gen_mult
    reg signed [KERNEL_WIDTH-1 : 0] krnl_reg;
    reg signed [PIXEL_WIDTH_EXTN-1 : 0] window_reg;

    always @(posedge clk) begin
        if (enable) begin
            krnl_reg <= krnl [(k * KERNEL_WIDTH) +: KERNEL_WIDTH];
            window_reg <= window [(k * PIXEL_WIDTH_EXTN) +: PIXEL_WIDTH_EXTN];
        end
    end

    
    (* use_dsp = "yes" *) wire signed [(OUT_WIDTH)-1:0] temp_mult;
    assign temp_mult = krnl_reg * window_reg;
    assign mult_out [(k * OUT_WIDTH) +: OUT_WIDTH] = temp_mult;
 end
endgenerate
endmodule




