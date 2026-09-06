module kernel_weights #(
    parameter KERNEL_WIDTH = 8,
    parameter KERNEL_SIZE  = 3
) (
    input  wire                               rst_n,
    input  wire                               clk,
    input  wire signed [KERNEL_WIDTH-1:0]     krnl_in,
    input  wire                               krnl_enable,
    output wire signed [(KERNEL_WIDTH*KERNEL_SIZE*KERNEL_SIZE)-1:0] krnl_out
);

    localparam KERNEL_FULL_SIZE = KERNEL_SIZE * KERNEL_SIZE;

    reg signed [KERNEL_WIDTH-1:0] krnl_win [0:KERNEL_FULL_SIZE-1];

    integer i;
    genvar k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < KERNEL_FULL_SIZE; i = i + 1) begin
                krnl_win[i] <= {KERNEL_WIDTH{1'b0}};
            end
        end
        else if (krnl_enable) begin
            for (i = 0; i < KERNEL_FULL_SIZE - 1; i = i + 1) begin
                krnl_win[i] <= krnl_win[i+1];
            end

            krnl_win[KERNEL_FULL_SIZE-1] <= krnl_in;
        end
    end

    generate
        for (k = 0; k < KERNEL_FULL_SIZE; k = k + 1) begin : gen_kernel_out
            assign krnl_out[(k*KERNEL_WIDTH) +: KERNEL_WIDTH] = krnl_win[k];
        end
    endgenerate

endmodule