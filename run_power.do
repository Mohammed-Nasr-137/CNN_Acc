# 1. Instruct Questa to monitor all inputs, outputs, and internal nets of the DUT
power add -in -out -internal /tb_cnn_top/dut/*

# 2. Run the simulation until the $finish command in your Verilog is reached
run -all

# 3. Export the recorded switching activity into a Backward SAIF file for Vivado
power report -all -bsaif cnn_activity.saif