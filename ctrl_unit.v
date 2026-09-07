module ctrl_unit #(
    parameter                       INPUT_ROWS      = 32,
    parameter                       INPUT_COLUMN    = 32,
    parameter                       KERNEL_SIZE     = 3
)(
    input                           clk,
    input                           rst_n,
    input                           valid_in,
    output reg                      valid_out
);

    localparam ROWS_WIDTH   = $clog2(INPUT_ROWS);
    localparam COLUMN_WIDTH = $clog2(INPUT_COLUMN);

    reg     [1:0]                   cs, ns;
    reg     [ROWS_WIDTH-1 : 0]      rows_counter;
    reg     [COLUMN_WIDTH-1 : 0]    column_counter;
    // reg                             counter_flag;
    // reg                             stall;
    reg                             column_counter_en;
    // reg                             row_counter_en;
    reg                             valid_out_comb;

    localparam IDLE         = 2'b00,
               PRE_LOAD     = 2'b01, // initial loading till the first valid window
               WINDOW_READY = 2'b11, // slide windows till a window isn't valid
               COLUMN_WRAP  = 2'b10; // handles moving the window to a new row

    // --- Sequential block ----------
    always @ (posedge clk) begin
        // --- Current state logic ----------
        if(!rst_n)
            cs              <= IDLE;
        else
            cs              <= ns;
        // --- Counters logic ----------
        if(!rst_n) begin
            rows_counter    <= {ROWS_WIDTH{1'b0}};
            column_counter  <= {COLUMN_WIDTH{1'b0}};
            valid_out       <= 'b0;
        end
        // else if(!counter_flag) begin
        //     rows_counter    <= {ROWS_WIDTH{1'b0}};
        //     column_counter  <= {COLUMN_WIDTH{1'b0}};
        else begin
            valid_out       <= valid_out_comb;

            if (cs == IDLE && !valid_in)
            begin
                rows_counter    <= {ROWS_WIDTH{1'b0}};
                column_counter  <= {COLUMN_WIDTH{1'b0}};
            end
            else if (column_counter_en)
            begin
                if (column_counter == INPUT_COLUMN - 1)
                begin
                    column_counter  <= {COLUMN_WIDTH{1'b0}};
                    rows_counter    <= (rows_counter == INPUT_ROWS - 1) ? {ROWS_WIDTH{1'b0}} : rows_counter + 1'b1;
                end
                else begin
                    column_counter <= column_counter + 1'b1;
                end
            end
        end
    end

    // --- Combinational block ----------
    always @ (*) begin
        valid_out_comb  = 1'b0;
        case(cs)
            IDLE: begin
                // stall               = 1'b1;
                // row_counter_en    = 'b0;
                column_counter_en = 'b0;
                if(valid_in) begin
                    // counter_flag    = 1'b1;
                    ns              = PRE_LOAD;
                    column_counter_en = 'b1;
                end
                else begin
                    // counter_flag    = 1'b0;
                    ns                = IDLE;
                    valid_out_comb    = 'b0;
                end
            end
            PRE_LOAD: begin
                // counter_flag        = 1'b1;
                // stall               = 1'b1;
                // row_counter_en    = 'b0;
                column_counter_en = 'b1;
                if(!valid_in) begin
                    // stall           = 1'b0;
                    ns                = PRE_LOAD;
                    column_counter_en = 'b0;
                end
                else if((rows_counter == (KERNEL_SIZE - 1)) && (column_counter == (KERNEL_SIZE - 1))) begin
                    valid_out_comb  = 1'b1;
                    ns              = WINDOW_READY;
                end
                else
                    ns              = PRE_LOAD;
            end
            WINDOW_READY: begin
                // counter_flag        = 1'b1;
                // stall               = 1'b1;
                column_counter_en = 'b1;
                valid_out_comb    = 1'b1;
                if(!valid_in) begin
                    // stall           = 1'b0;
                    ns              = WINDOW_READY;
                    valid_out_comb  = 1'b0;
                    column_counter_en = 'b0;
                end
                else if((rows_counter == INPUT_ROWS - 1) && (column_counter == INPUT_COLUMN - 1))
                begin
                    ns              = IDLE;
                end
                else if(column_counter == INPUT_COLUMN - 1)
                begin
                    ns              = COLUMN_WRAP;
                    // valid_out_comb    = 'b0;
                end
                else
                    ns              = WINDOW_READY;
            end
            COLUMN_WRAP: begin
                // counter_flag        = 1'b1;
                // stall               = 1'b1;
                valid_out_comb    = 1'b0;
                column_counter_en = 'b1;
                if(!valid_in) begin
                    // stall           = 1'b0;
                    ns              = COLUMN_WRAP;
                    column_counter_en = 'b0;
                end
                else if(column_counter == (KERNEL_SIZE - 1)) begin
                    valid_out_comb  = 1'b1;
                    ns              = WINDOW_READY;
                end
                else
                    ns              = COLUMN_WRAP;
            end
        endcase
    end
endmodule