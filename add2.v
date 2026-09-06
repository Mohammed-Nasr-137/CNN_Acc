
// ============================================================
// 2-INPUT ADDER
// ============================================================
module add2 #(
    parameter DATA_WIDTH = 16
)(
    input wire signed  [DATA_WIDTH-1:0] A,
    input wire signed  [DATA_WIDTH-1:0] B,
    output wire signed [DATA_WIDTH+1:0] Y
);

   assign Y = {{2{A[DATA_WIDTH-1]}}, A} + {{2{B[DATA_WIDTH-1]}}, B} ;

endmodule

