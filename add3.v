
// ============================================================
// 3-INPUT ADDER
// ============================================================
module add3 #(
    parameter DATA_WIDTH = 16
)(
    input  wire signed [DATA_WIDTH-1:0] A,
    input  wire signed  [DATA_WIDTH-1:0] B,
    input  wire signed  [DATA_WIDTH-1:0] C,
    output wire signed  [DATA_WIDTH+1:0] Y
);
//(* keep = "true" *)
    assign Y = {{2{A[DATA_WIDTH-1]}}, A} + {{2{B[DATA_WIDTH-1]}}, B} + {{2{C[DATA_WIDTH-1]}}, C};

endmodule

