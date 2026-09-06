vlib work
vlog -v  add2.v add3.v pipeline_stage.v pipelined_kernel_alu.v reduction_pipeline.v tb.sv
vsim tb_pipelined_kernel_alu

run -all
