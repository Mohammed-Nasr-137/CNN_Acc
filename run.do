# ==============================================================================
# QuestaSim / ModelSim Automated Build & Run Script
# ==============================================================================

# 1. Quit current simulation if running and clear console
quit -sim
.main clear

# 2. Create and map the work library
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# 3. Compile RTL and Testbench in Dependency Order (Leaves -> Root -> TB)
# -sv flag enables SystemVerilog IEEE 1800-2012 constructs (queues, packages)
puts "\n--- COMPILING RTL MODULES ---"
vlog -sv line_buffer.v
vlog -sv line_buffers_top.v
vlog -sv ctrl_unit.v
vlog -sv window_reg.v
vlog -sv kernel_weights.v
vlog -sv zero_extention.v
vlog -sv multiplier.v
vlog -sv stage2_reg.v
vlog -sv add2.v
vlog -sv add3.v
vlog -sv pipeline_stage.v
vlog -sv reduction_pipeline.v
vlog -sv pipelined_kernel_alu.v
vlog -sv cnn_top.v
vlog -sv fifo.v

puts "\n--- COMPILING TESTBENCH ---"
vlog -sv tb_cnn_top.sv

# 4. Elaborate and Optimize the Design
# +acc provides full visibility for waveform probing without disabling optimizations
puts "\n--- ELABORATING DESIGN ---"
vsim -voptargs="+acc" work.tb_cnn_top

# 5. Configure Waveform Viewer
puts "\n--- CONFIGURING WAVEFORMS ---"
# Clocks & Global Controls
add wave -divider "GLOBAL CONTROLS"
add wave -format Logic /tb_cnn_top/clk
add wave -format Logic /tb_cnn_top/rst_n

# Top-Level Streaming Input Interface
add wave -divider "INPUT STREAM"
add wave -format Logic /tb_cnn_top/valid_in
add wave -format Literal -radix unsigned /tb_cnn_top/pixel_in
add wave -format Logic /tb_cnn_top/load_w
add wave -format Literal -radix decimal /tb_cnn_top/weight_in

# Accelerator Core Internal State Tracking
add wave -divider "INTERNAL RASTER STATE"
add wave -format Literal -radix unsigned /tb_cnn_top/dut/ctrl/rows_counter
add wave -format Literal -radix unsigned /tb_cnn_top/dut/ctrl/column_counter
add wave -format Literal -radix ascii /tb_cnn_top/dut/ctrl/cs
add wave -format Logic /tb_cnn_top/dut/valid_window

# Pipelined Valid Tags (Tracking sideband delay)
add wave -divider "VALID PIPE TAGS"
add wave -format Logic /tb_cnn_top/dut/adder_tree/u_reduction_pipeline/valid_out

# Top-Level Streaming Output Interface
add wave -divider "OUTPUT STREAM"
add wave -format Logic /tb_cnn_top/valid_out
add wave -format Literal -radix decimal /tb_cnn_top/pixel_out

# Verification Progress
add wave -divider "VERIFICATION SCORE"
add wave -format Literal -radix decimal /tb_cnn_top/match_count
add wave -format Literal -radix decimal /tb_cnn_top/mismatch_count

# 6. Run Simulation to Completion
puts "\n--- EXECUTING SIMULATION ---"
run -all

# 7. Zoom full to fit waveform display
wave zoom full