# Fixed and Optimized DDR5 Constraints File

# Clock definitions - using separate clock ports
create_clock -period 3.333 -name CLK_P [get_ports clk] -waveform {0.000 1.666}
create_clock -period 1.25 -name DDR5_CLK_P [get_ports DDR5_CLK_P] -waveform {0.000 0.625}

# Clock uncertainty
set_clock_uncertainty -setup 0.050 [get_clocks CLK_P]
set_clock_uncertainty -hold 0.030 [get_clocks CLK_P]
set_clock_uncertainty -setup 0.080 [get_clocks DDR5_CLK_P]
set_clock_uncertainty -hold 0.050 [get_clocks DDR5_CLK_P]

# Asynchronous clock groups
set_clock_groups -asynchronous -group [get_clocks CLK_P] -group [get_clocks DDR5_CLK_P]

# DDR5 Clock pins - FIXED pin conflict
set_property PACKAGE_PIN AN8 [get_ports DDR5_CLK_P]
set_property PACKAGE_PIN AM8 [get_ports DDR5_CLK_N]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports DDR5_CLK_P]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports DDR5_CLK_N]

# System clock pin
set_property PACKAGE_PIN K21 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports clk]

# DDR5 Control signals - FIXED RAS_N pin conflict
set_property PACKAGE_PIN B7 [get_ports DDR5_RST_N]
set_property IOSTANDARD SSTL12_DCI [get_ports DDR5_RST_N]

set_property PACKAGE_PIN AN7 [get_ports DDR5_CAS_N]
set_property IOSTANDARD SSTL12_DCI [get_ports DDR5_CAS_N]

set_property PACKAGE_PIN AL7 [get_ports DDR5_RAS_N]  # Changed from AM8 to AL7
set_property PACKAGE_PIN AL8 [get_ports DDR5_WE_N]
set_property IOSTANDARD SSTL12_DCI [get_ports DDR5_RAS_N]
set_property IOSTANDARD SSTL12_DCI [get_ports DDR5_WE_N]

# DDR5 Address pins
set_property PACKAGE_PIN AN9 [get_ports {DDR5_ADDR[0]}]
set_property PACKAGE_PIN AP9 [get_ports {DDR5_ADDR[1]}]
set_property PACKAGE_PIN AL9 [get_ports {DDR5_ADDR[2]}]
set_property PACKAGE_PIN AL10 [get_ports {DDR5_ADDR[3]}]
set_property PACKAGE_PIN AM10 [get_ports {DDR5_ADDR[4]}]
set_property PACKAGE_PIN AN10 [get_ports {DDR5_ADDR[5]}]
set_property PACKAGE_PIN AP10 [get_ports {DDR5_ADDR[6]}]
set_property PACKAGE_PIN AM11 [get_ports {DDR5_ADDR[7]}]
set_property PACKAGE_PIN AN11 [get_ports {DDR5_ADDR[8]}]
set_property PACKAGE_PIN AP11 [get_ports {DDR5_ADDR[9]}]
set_property PACKAGE_PIN AL11 [get_ports {DDR5_ADDR[10]}]
set_property PACKAGE_PIN AQ12 [get_ports {DDR5_ADDR[11]}]
set_property PACKAGE_PIN AM12 [get_ports {DDR5_ADDR[12]}]
set_property PACKAGE_PIN AN12 [get_ports {DDR5_ADDR[13]}]

set_property IOSTANDARD SSTL12_DCI [get_ports {DDR5_ADDR[*]}]

# DDR5 Bank Address pins
set_property PACKAGE_PIN AP12 [get_ports {DDR5_BA[0]}]
set_property PACKAGE_PIN AL13 [get_ports {DDR5_BA[1]}]
set_property PACKAGE_PIN AM13 [get_ports {DDR5_BA[2]}]
set_property PACKAGE_PIN AN13 [get_ports {DDR5_BA[3]}]

set_property IOSTANDARD SSTL12_DCI [get_ports {DDR5_BA[*]}]

# DDR5 Data pins (0-31)
set_property PACKAGE_PIN AJ6 [get_ports {DDR5_DQ[0]}]
set_property PACKAGE_PIN AK6 [get_ports {DDR5_DQ[1]}]
set_property PACKAGE_PIN AJ7 [get_ports {DDR5_DQ[2]}]
set_property PACKAGE_PIN AK7 [get_ports {DDR5_DQ[3]}]
set_property PACKAGE_PIN AH6 [get_ports {DDR5_DQ[4]}]
set_property PACKAGE_PIN AH7 [get_ports {DDR5_DQ[5]}]
set_property PACKAGE_PIN AG6 [get_ports {DDR5_DQ[6]}]
set_property PACKAGE_PIN AG7 [get_ports {DDR5_DQ[7]}]
set_property PACKAGE_PIN AF6 [get_ports {DDR5_DQ[8]}]
set_property PACKAGE_PIN AF7 [get_ports {DDR5_DQ[9]}]
set_property PACKAGE_PIN AE6 [get_ports {DDR5_DQ[10]}]
set_property PACKAGE_PIN AE7 [get_ports {DDR5_DQ[11]}]
set_property PACKAGE_PIN AD6 [get_ports {DDR5_DQ[12]}]
set_property PACKAGE_PIN AD7 [get_ports {DDR5_DQ[13]}]
set_property PACKAGE_PIN AC6 [get_ports {DDR5_DQ[14]}]
set_property PACKAGE_PIN AC7 [get_ports {DDR5_DQ[15]}]
set_property PACKAGE_PIN AB6 [get_ports {DDR5_DQ[16]}]
set_property PACKAGE_PIN AB7 [get_ports {DDR5_DQ[17]}]
set_property PACKAGE_PIN AA6 [get_ports {DDR5_DQ[18]}]
set_property PACKAGE_PIN AA7 [get_ports {DDR5_DQ[19]}]
set_property PACKAGE_PIN Y6 [get_ports {DDR5_DQ[20]}]
set_property PACKAGE_PIN Y7 [get_ports {DDR5_DQ[21]}]
set_property PACKAGE_PIN W6 [get_ports {DDR5_DQ[22]}]
set_property PACKAGE_PIN W7 [get_ports {DDR5_DQ[23]}]
set_property PACKAGE_PIN V6 [get_ports {DDR5_DQ[24]}]
set_property PACKAGE_PIN V7 [get_ports {DDR5_DQ[25]}]
set_property PACKAGE_PIN U6 [get_ports {DDR5_DQ[26]}]
set_property PACKAGE_PIN U7 [get_ports {DDR5_DQ[27]}]
set_property PACKAGE_PIN T6 [get_ports {DDR5_DQ[28]}]
set_property PACKAGE_PIN T7 [get_ports {DDR5_DQ[29]}]
set_property PACKAGE_PIN R6 [get_ports {DDR5_DQ[30]}]
set_property PACKAGE_PIN R7 [get_ports {DDR5_DQ[31]}]

# DDR5 Data pins (32-63)
set_property PACKAGE_PIN AJ8 [get_ports {DDR5_DQ[32]}]
set_property PACKAGE_PIN AK8 [get_ports {DDR5_DQ[33]}]
set_property PACKAGE_PIN AJ9 [get_ports {DDR5_DQ[34]}]
set_property PACKAGE_PIN AK9 [get_ports {DDR5_DQ[35]}]
set_property PACKAGE_PIN AH8 [get_ports {DDR5_DQ[36]}]
set_property PACKAGE_PIN AH9 [get_ports {DDR5_DQ[37]}]
set_property PACKAGE_PIN AG8 [get_ports {DDR5_DQ[38]}]
set_property PACKAGE_PIN AG9 [get_ports {DDR5_DQ[39]}]
set_property PACKAGE_PIN AF8 [get_ports {DDR5_DQ[40]}]
set_property PACKAGE_PIN AF9 [get_ports {DDR5_DQ[41]}]
set_property PACKAGE_PIN AE9 [get_ports {DDR5_DQ[42]}]
set_property PACKAGE_PIN AE8 [get_ports {DDR5_DQ[43]}]
set_property PACKAGE_PIN AD8 [get_ports {DDR5_DQ[44]}]
set_property PACKAGE_PIN AD9 [get_ports {DDR5_DQ[45]}]
set_property PACKAGE_PIN AC8 [get_ports {DDR5_DQ[46]}]
set_property PACKAGE_PIN AC9 [get_ports {DDR5_DQ[47]}]
set_property PACKAGE_PIN AB8 [get_ports {DDR5_DQ[48]}]
set_property PACKAGE_PIN AB9 [get_ports {DDR5_DQ[49]}]
set_property PACKAGE_PIN AA8 [get_ports {DDR5_DQ[50]}]
set_property PACKAGE_PIN AA9 [get_ports {DDR5_DQ[51]}]
set_property PACKAGE_PIN Y8 [get_ports {DDR5_DQ[52]}]
set_property PACKAGE_PIN Y9 [get_ports {DDR5_DQ[53]}]
set_property PACKAGE_PIN W8 [get_ports {DDR5_DQ[54]}]
set_property PACKAGE_PIN W9 [get_ports {DDR5_DQ[55]}]
set_property PACKAGE_PIN V8 [get_ports {DDR5_DQ[56]}]
set_property PACKAGE_PIN V9 [get_ports {DDR5_DQ[57]}]
set_property PACKAGE_PIN U8 [get_ports {DDR5_DQ[58]}]
set_property PACKAGE_PIN U9 [get_ports {DDR5_DQ[59]}]
set_property PACKAGE_PIN T8 [get_ports {DDR5_DQ[60]}]
set_property PACKAGE_PIN T9 [get_ports {DDR5_DQ[61]}]
set_property PACKAGE_PIN R8 [get_ports {DDR5_DQ[62]}]
set_property PACKAGE_PIN R9 [get_ports {DDR5_DQ[63]}]

set_property IOSTANDARD POD12_DCI [get_ports {DDR5_DQ[*]}]

# System reset
set_property PACKAGE_PIN K22 [get_ports rst]
set_property IOSTANDARD LVCMOS18 [get_ports rst]

# CPU Interface
set_property PACKAGE_PIN C22 [get_ports CPU_VALID]
set_property PACKAGE_PIN D22 [get_ports CPU_WE]
set_property PACKAGE_PIN E22 [get_ports CPU_READY]

set_property IOSTANDARD LVCMOS33 [get_ports CPU_VALID]
set_property IOSTANDARD LVCMOS33 [get_ports CPU_WE]
set_property IOSTANDARD LVCMOS33 [get_ports CPU_READY]

# Timing constraints - DDR5 Data (bidirectional)
set_input_delay -clock [get_clocks DDR5_CLK_P] -max 0.300 [get_ports {DDR5_DQ[*]}]
set_input_delay -clock [get_clocks DDR5_CLK_P] -min -0.300 [get_ports {DDR5_DQ[*]}]
set_input_delay -clock [get_clocks DDR5_CLK_P] -max 0.300 [get_ports {DDR5_DQ[*]}] -clock_fall -add_delay
set_input_delay -clock [get_clocks DDR5_CLK_P] -min -0.300 [get_ports {DDR5_DQ[*]}] -clock_fall -add_delay

set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.300 [get_ports {DDR5_DQ[*]}]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.300 [get_ports {DDR5_DQ[*]}]
set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.300 [get_ports {DDR5_DQ[*]}] -clock_fall -add_delay
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.300 [get_ports {DDR5_DQ[*]}] -clock_fall -add_delay

# DDR5 Address and Control timing
set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.400 [get_ports {DDR5_ADDR[*]}]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.400 [get_ports {DDR5_ADDR[*]}]
set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.400 [get_ports {DDR5_BA[*]}]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.400 [get_ports {DDR5_BA[*]}]

set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.350 [get_ports DDR5_RAS_N]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.350 [get_ports DDR5_RAS_N]
set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.350 [get_ports DDR5_CAS_N]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.350 [get_ports DDR5_CAS_N]
set_output_delay -clock [get_clocks DDR5_CLK_P] -max 0.350 [get_ports DDR5_WE_N]
set_output_delay -clock [get_clocks DDR5_CLK_P] -min -0.350 [get_ports DDR5_WE_N]

# Clock routing - FIXED net names to match actual ports
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_IBUF]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets DDR5_CLK_P_IBUF]

# High priority nets
set_property HIGH_PRIORITY true [get_nets -hier *clk*]
set_property HIGH_PRIORITY true [get_nets -hier *rst*]

# Multi-cycle paths - CONSOLIDATED to avoid duplicates
set_multicycle_path -setup 2 -through [get_pins -hier *refresh_cnt*] -quiet
set_multicycle_path -hold 1 -through [get_pins -hier *refresh_cnt*] -quiet

set_multicycle_path -setup 4 -from [get_pins -hier *curr_state*] -to [get_ports {DDR5_ADDR[*]}] -quiet
set_multicycle_path -hold 3 -from [get_pins -hier *curr_state*] -to [get_ports {DDR5_ADDR[*]}] -quiet

set_multicycle_path -setup 3 -from [get_pins -hier *DDR5*] -to [get_ports {DDR5_*}] -quiet
set_multicycle_path -hold 2 -from [get_pins -hier *DDR5*] -to [get_ports {DDR5_*}] -quiet

# False path constraints
set_false_path -from [get_ports rst]
set_false_path -to [get_ports DDR5_RST_N]
set_false_path -from [get_ports CPU_*] -to [get_clocks DDR5_CLK_P]
set_false_path -from [get_clocks DDR5_CLK_P] -to [get_ports CPU_*]

# Max delay for clock domain crossings
set_max_delay -from [get_clocks SYS_CLK_P] -to [get_clocks DDR5_CLK_P] 1.000
set_max_delay -from [get_clocks DDR5_CLK_P] -to [get_clocks SYS_CLK_P] 3.000

# I/O properties for signal integrity
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {DDR5_ADDR[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {DDR5_BA[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports DDR5_RAS_N]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports DDR5_CAS_N]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports DDR5_WE_N]

set_property SLEW FAST [get_ports {DDR5_ADDR[*]}]
set_property SLEW FAST [get_ports {DDR5_BA[*]}]
set_property SLEW FAST [get_ports {DDR5_DQ[*]}]
set_property SLEW FAST [get_ports DDR5_RAS_N]
set_property SLEW FAST [get_ports DDR5_CAS_N]
set_property SLEW FAST [get_ports DDR5_WE_N]

# Configuration settings
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 85.0 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# Implementation strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Internal voltage reference
set_property INTERNAL_VREF 0.6 [get_iobanks 70]
set_property INTERNAL_VREF 0.6 [get_iobanks 71]
