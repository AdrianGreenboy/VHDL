# SERDES_256G - CDC constraints (scoped to the serdes256g_top instance:
#   read_xdc -ref serdes256g_top vivado/serdes256g_cdc.xdc)
#
# The lane recovered clocks, tx_clk and rx_clk must NOT be put in one
# set_clock_groups -asynchronous together with these constraints: clock groups
# override set_max_delay and would leave the gray pointers unbounded.
# 4.0 ns = one lane-word period at 32 Gb/s; scale it with the line rate.

# gray pointers of the deskew FIFOs
set_max_delay -datapath_only 4.0 \
  -from [get_cells -hier -filter {NAME =~ *u_fifo/wgray_reg[*]}] \
  -to   [get_cells -hier -filter {NAME =~ *u_fifo/wg_r1_reg[*]}]
set_max_delay -datapath_only 4.0 \
  -from [get_cells -hier -filter {NAME =~ *u_fifo/rgray_reg[*]}] \
  -to   [get_cells -hier -filter {NAME =~ *u_fifo/rg_w1_reg[*]}]

# distributed-RAM read data into rx_clk (stable before 'empty' drops): data
# word into s1_word and the marker flag into the deskew FSM / read pointers
# (leaf RAM clock pins only: the RAM macro cells are not valid startpoints)
set_max_delay -datapath_only 4.0 \
  -from [get_pins -hier -filter {NAME =~ *u_fifo/mem_reg*/CLK && IS_LEAF}]

# single-bit status synchronisers
set_false_path -to [get_cells -hier -filter {NAME =~ *amlk_m_reg[*]}]
set_false_path -to [get_cells -hier -filter {NAME =~ *al_tx_m_reg}]

# lane resets: asynchronous assert, synchronous release
set_false_path -to [get_pins -hier -filter {NAME =~ *lrst_m_reg[*]/PRE}]
set_false_path -to [get_pins -hier -filter {NAME =~ *lrst_s_reg[*]/PRE}]
