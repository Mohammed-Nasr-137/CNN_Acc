module line_buffer #(
    parameter   DATA_WIDTH  = 8,
    parameter   LINE_DEPTH  = 32
)(
    input                       clk,
    input                       enable,
    input   [DATA_WIDTH-1 : 0]  data_in,
    output  [DATA_WIDTH-1 : 0]  data_out
);

    // --- Declaration ---------
    (* shreg_extract = "yes", srl_style = "srl" *) 
    reg [DATA_WIDTH-1 : 0]  srl_reg [LINE_DEPTH-1 : 0];
    integer i;
    genvar  j;


    always @ (posedge clk) begin
        if (enable) begin 
            srl_reg[0] <= data_in;

            for (i = 0; i < LINE_DEPTH - 1; i = i + 1) begin
                srl_reg[i+1] <= srl_reg[i];
            end
        end
    end

    // --- Output logic ---------
    assign data_out = srl_reg[LINE_DEPTH-1];
endmodule