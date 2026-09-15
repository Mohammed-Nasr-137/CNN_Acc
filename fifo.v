module output_fifo #(
    parameter IMAGE_ROWS  = 32,
    parameter IMAGE_COLS  = 32,
    parameter KERNEL_SIZE = 3,
    parameter OUTPUT_SIZE = 16
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [OUTPUT_SIZE-1:0] adder_pixel_in, // output of adder stages, input of fifo
    input  wire                   adder_valid_in, // output of adder stages, input of fifo
    output reg  [OUTPUT_SIZE-1:0] fifo_pixel_out,
    output reg                    fifo_valid_out
);

    localparam TOTAL_DELAY       = (IMAGE_ROWS-KERNEL_SIZE) * (KERNEL_SIZE-1);
    localparam FIFO_DEPTH        = 2**($clog2(TOTAL_DELAY));
    localparam ADDR_WIDTH        = $clog2(FIFO_DEPTH);
    localparam COUNTER_WIDTH     = $clog2(TOTAL_DELAY+1);
    localparam TOTAL_OUTPUTS     = (IMAGE_ROWS - KERNEL_SIZE + 1) * (IMAGE_COLS - KERNEL_SIZE + 1);
    localparam OUT_COUNTER_WIDTH = $clog2(TOTAL_OUTPUTS + 1);
    
    localparam integer LUT6_DEPTH    = 64;
    localparam integer BRAM_DEPTH    = 1024;
    localparam integer BRAM_WIDTH    = 18;
    localparam integer BRAM_FOM_COST = 50;
    localparam integer LUT_PORTS     = 2;   // independent read+write addressing

    localparam integer LUT_COST  = LUT_PORTS * OUTPUT_SIZE
                                * ((FIFO_DEPTH + LUT6_DEPTH-1) / LUT6_DEPTH);
    localparam integer BRAM_COST = BRAM_FOM_COST
                                * ((OUTPUT_SIZE + BRAM_WIDTH-1) / BRAM_WIDTH)
                                * ((FIFO_DEPTH  + BRAM_DEPTH-1) / BRAM_DEPTH);

    (* ram_style = (LUT_COST <= BRAM_COST) ? "distributed" : "block" *)
    reg [OUTPUT_SIZE-1:0] memory [0:FIFO_DEPTH-1];

    // MSB for phase tracking to prevent pointer collision
    reg [ADDR_WIDTH:0]          wr_ptr;
    reg [ADDR_WIDTH:0]          rd_ptr;
    reg                         output_active;     // high if the total delay wait is over and fifo is outputting
    reg [COUNTER_WIDTH-1:0]     gap_counter;       // counts till total delay to start outputting
    reg [OUT_COUNTER_WIDTH-1:0] out_pixel_counter; // tracks the number of outputs to terminate

    wire                        fifo_empty;        // prevents rd_ptr form outrunning wr_ptr
    wire                        read_en;           // read only when memory is prefilled, has data, and frame isn't finished

    // write
    always @(posedge clk)
    begin
        if (!rst_n)
        begin
            wr_ptr <= 'b0;
        end
        else if (adder_valid_in)
        begin
            wr_ptr <= wr_ptr + 'b1;
        end
    end

    always @(posedge clk)
    begin
        if (adder_valid_in)
        begin
            memory[wr_ptr[ADDR_WIDTH-1:0]] <= adder_pixel_in;
        end
    end

    // progress tracking
    always @(posedge clk)
    begin
        if (!rst_n)
        begin
            gap_counter       <= 'b0;
            output_active     <= 'b0;
            out_pixel_counter <= 'b0;
        end
        else
        begin
            // prefill
            if (adder_valid_in && !output_active)
            begin
                if (gap_counter == TOTAL_DELAY - 1)
                begin
                    output_active <= 1'b1;
                end
                else
                begin
                    gap_counter <= gap_counter + 1'b1;
                end
            end

            // track number of outputs
            if (read_en) 
            begin
                out_pixel_counter <= out_pixel_counter + 'b1;
            end

            // reset after end of frame
            if ((out_pixel_counter >= TOTAL_OUTPUTS) && fifo_empty)
            begin
                output_active     <= 'b0;
                gap_counter       <= 'b0;
                out_pixel_counter <= 'b0;
            end
        end
    end

    // read
    always @(posedge clk)
    begin
        if (!rst_n)
        begin
            rd_ptr         <= 'b0;
            fifo_valid_out <= 'b0;
            fifo_pixel_out <= 'b0;
        end 
        else
        begin
            fifo_valid_out <= read_en;

            if (read_en)
            begin
                fifo_pixel_out <= memory[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr         <= rd_ptr + 'b1;
            end
        end
    end

    assign fifo_empty     = (wr_ptr == rd_ptr);
    assign read_en        = output_active && !fifo_empty && (out_pixel_counter < TOTAL_OUTPUTS);
endmodule
