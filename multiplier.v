module multiplier  #(parameter KERNEL_WIDTH     = 8,
                     parameter PIXEL_WIDTH_EXTN = 9,
                     parameter OUT_WIDTH        = KERNEL_WIDTH + PIXEL_WIDTH_EXTN,
                     parameter KERNEL_SIZE      = 3
                     

) ( input wire signed [(PIXEL_WIDTH_EXTN*KERNEL_SIZE*KERNEL_SIZE)-1:0] window,

    input wire signed [(KERNEL_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] krnl,

    // input wire  valid_krnl,

    // input wire  valid_win,
    input wire  enable,

    output wire signed [(OUT_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] mult_out

);

// wire valid ;

// assign valid = valid_krnl && valid_win;

genvar  k;

localparam KERNEL_FULL_SIZE = KERNEL_SIZE * KERNEL_SIZE;

generate 
 for ( k = 0 ; k < KERNEL_FULL_SIZE ; k = k + 1) begin : gen_mult
    wire signed [KERNEL_WIDTH-1 : 0] krnl_gen;

    wire signed [PIXEL_WIDTH_EXTN-1 : 0] window_gen;

    assign krnl_gen = enable ? krnl [(k * KERNEL_WIDTH) +: KERNEL_WIDTH] : {KERNEL_WIDTH{1'b0}};
   
    assign window_gen = enable ? window [(k * PIXEL_WIDTH_EXTN) +: PIXEL_WIDTH_EXTN] : {PIXEL_WIDTH_EXTN{1'b0}};

    (* use_dsp = "no" *) wire signed [(OUT_WIDTH)-1:0] temp_mult;
    assign temp_mult = krnl_gen * window_gen;
    assign mult_out [(k * OUT_WIDTH) +: OUT_WIDTH] = temp_mult;
 end
endgenerate
endmodule




