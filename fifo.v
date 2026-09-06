module output_fifo #(
    parameter IMAGE_ROWS  = 32,
    parameter KERNEL_SIZE = 3,
    parameter OUTPUT_SIZE = 16
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [OUTPUT_SIZE-1:0] adder_pixel_in, // output of adder stages, input of fifo
    input  wire                   adder_valid_in, // output of adder stages, input of fifo
    output wire [OUTPUT_SIZE-1:0] fifo_pixel_out,
    output reg                    fifo_valid_out
);

    localparam TOTAL_DELAY   = (IMAGE_ROWS-KERNEL_SIZE) * (KERNEL_SIZE-1);
    localparam FIFO_DEPTH    = 2**($clog2(TOTAL_DELAY));
    localparam ADDR_WIDTH    = $clog2(FIFO_DEPTH);
    localparam COUNTER_WIDTH = $clog2(TOTAL_DELAY);
    
    (* ram_style = (TOTAL_DELAY < 512) ? "distributed" : "block" *)
    reg [OUTPUT_SIZE-1:0] memory [0:FIFO_DEPTH-1];

    // MSB for phase tracking to prevent pointer collision
    reg [ADDR_WIDTH:0]      wr_ptr;
    reg [ADDR_WIDTH:0]      rd_ptr;
    reg                     output_active; // high if the total delay wait is over and fifo is outputting
    reg [COUNTER_WIDTH-1:0] gap_counter;   // counts till total delay to start outputting

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            wr_ptr         <= 'b0;
            rd_ptr         <= 'b0;
            fifo_valid_out <= 'b0;
            output_active  <= 'b0;
            gap_counter    <= 'b0;
        end
        else
        begin
            // continuous writing
            if (adder_valid_in)
            begin
                memory[wr_ptr] <= adder_pixel_in;
                wr_ptr         <= wr_ptr + 1;
            end
            
            // trigger output 
            if (adder_valid_in && !output_active)
            begin
                if (gap_counter == TOTAL_DELAY)
                begin
                    output_active = 'b1;
                end
                else
                begin
                    gap_counter <= gap_counter + 1;
                end
            end

            // continuous reading
            if (output_active)
            begin
                fifo_valid_out <= 'b1;
                rd_ptr         <= rd_ptr + 1;

                // terminate when read pointer catches write pointer
                if (rd_ptr == wr_ptr - 1 && !adder_valid_in)
                begin
                    output_active  <= 'b0;
                    fifo_valid_out <= 'b0;
                    gap_counter    <= 'b0;
                end
            end
            else
            begin
                fifo_valid_out <= 'b0;
            end
        end
    end

    assign fifo_pixel_out = memory[rd_ptr[ADDR_WIDTH-1:0]];
endmodule
