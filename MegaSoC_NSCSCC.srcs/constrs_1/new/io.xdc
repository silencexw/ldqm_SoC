set_property BITSTREAM.Config.SPI_BUSWIDTH 4 [current_design] 
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# clock constraint is done in Clocking Wizard
set_property -dict {PACKAGE_PIN AC19 IOSTANDARD LVCMOS33} [get_ports clk_100m] 
set_property -dict {PACKAGE_PIN Y3 IOSTANDARD LVCMOS33} [get_ports sys_rstn]

set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS33} [get_ports SPI_CLK]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports SPI_MISO]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports SPI_MOSI]
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVCMOS33} [get_ports {SPI_CS[0]}]
# FPGA_EXT0_IO11
set_property -dict {PACKAGE_PIN W23 IOSTANDARD LVCMOS33} [get_ports {SPI_CS[1]}]
# FPGA_EXT0_IO13
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33} [get_ports {SPI_CS[2]}]
# FPGA_EXT0_IO15
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports {SPI_CS[3]}]

set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports UART_TX]
set_property -dict {PACKAGE_PIN AA23 IOSTANDARD LVCMOS33} [get_ports UART_RX]

create_clock -period 40.000 -name mii_tx_clk [get_ports mii_tx_clk]
create_clock -period 40.000 -name mii_rx_clk [get_ports mii_rx_clk]

set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports mii_tx_clk]
set_property -dict {PACKAGE_PIN AF18 IOSTANDARD LVCMOS33} [get_ports {mii_txd[0]}]
set_property -dict {PACKAGE_PIN AE18 IOSTANDARD LVCMOS33} [get_ports {mii_txd[1]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports {mii_txd[2]}]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {mii_txd[3]}]
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS33} [get_ports mii_tx_en]
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33} [get_ports mii_tx_er]
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33} [get_ports mii_rx_clk]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {mii_rxd[0]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33 PULLDOWN TRUE} [get_ports {mii_rxd[1]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33 PULLDOWN TRUE} [get_ports {mii_rxd[2]}]
set_property -dict {PACKAGE_PIN V3 IOSTANDARD LVCMOS33 PULLDOWN TRUE} [get_ports {mii_rxd[3]}]
set_property -dict {PACKAGE_PIN AE22 IOSTANDARD LVCMOS33} [get_ports mii_rxdv]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports mii_rx_err]
set_property -dict {PACKAGE_PIN AF20 IOSTANDARD LVCMOS33 PULLDOWN TRUE} [get_ports mii_crs]
set_property -dict {PACKAGE_PIN Y15 IOSTANDARD LVCMOS33} [get_ports mii_col]
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVCMOS33} [get_ports MDC]
set_property -dict {PACKAGE_PIN W1 IOSTANDARD LVCMOS33} [get_ports MDIO]
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS33} [get_ports mii_phy_rstn]

set_input_delay -clock mii_rx_clk -min 10  [get_ports [list mii_rxdv  mii_rx_err mii_rxd*]]
set_input_delay -clock mii_rx_clk -max [expr 40-10]  [get_ports [list mii_rxdv  mii_rx_err mii_rxd*]]
set_output_delay -clock mii_tx_clk -min 0  [get_ports [list mii_tx_en  mii_txd*]]
set_output_delay -clock mii_tx_clk -max 12  [get_ports [list mii_tx_en  mii_txd*]]

set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS33} [get_ports {SD_DAT[0]}]
set_property -dict {PACKAGE_PIN V21 IOSTANDARD LVCMOS33} [get_ports {SD_DAT[1]}]
set_property -dict {PACKAGE_PIN U24 IOSTANDARD LVCMOS33} [get_ports {SD_DAT[2]}]
set_property -dict {PACKAGE_PIN W26 IOSTANDARD LVCMOS33} [get_ports {SD_DAT[3]}]
set_property -dict {PACKAGE_PIN Y26 IOSTANDARD LVCMOS33} [get_ports SD_CMD]
set_property -dict {PACKAGE_PIN AB26 IOSTANDARD LVCMOS33} [get_ports SD_CLK]

# gpio[0..3] = LED0..3, gpio[4..7] = Switch0..3
set_property -dict {PACKAGE_PIN K23 IOSTANDARD LVCMOS33} [get_ports {gpio[0]}]
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS33} [get_ports {gpio[1]}]
set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS33} [get_ports {gpio[2]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports {gpio[3]}]
set_property -dict {PACKAGE_PIN Y6 IOSTANDARD LVCMOS33} [get_ports {gpio[4]}]
set_property -dict {PACKAGE_PIN AA7 IOSTANDARD LVCMOS33} [get_ports {gpio[5]}]
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports {gpio[6]}]
set_property -dict {PACKAGE_PIN AB6 IOSTANDARD LVCMOS33} [get_ports {gpio[7]}]

# FPGA_EXT0_IO0
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVCMOS33} [get_ports CDBUS_tx]
# FPGA_EXT0_IO1
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports CDBUS_rx]
# FPGA_EXT0_IO2
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports CDBUS_tx_en]
# FPGA_EXT0_IO3
set_property -dict {PACKAGE_PIN AD25 IOSTANDARD LVCMOS33} [get_ports i2cm_scl]
# FPGA_EXT0_IO4
set_property -dict {PACKAGE_PIN AE25 IOSTANDARD LVCMOS33} [get_ports i2cm_sda]

# vga interface (DAC with resistors)
set vga_clk vga_clk_clk_gen_1
set_output_delay -clock $vga_clk -min -add_delay -1.000 [get_ports {VGA_*}]
set_output_delay -clock $vga_clk -max -add_delay 2.000 [get_ports {VGA_*}]
# red
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {VGA_R[3]}]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {VGA_R[2]}]
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS33} [get_ports {VGA_R[1]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS33} [get_ports {VGA_R[0]}]
# green
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {VGA_G[3]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {VGA_G[2]}]
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS33} [get_ports {VGA_G[1]}]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {VGA_G[0]}]
# blue
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {VGA_B[3]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS33} [get_ports {VGA_B[2]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {VGA_B[1]}]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD LVCMOS33} [get_ports {VGA_B[0]}]
# sync
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports VGA_HSYNC]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33} [get_ports VGA_VSYNC]

# PS/2 ports
set_property -dict {PACKAGE_PIN AD1 IOSTANDARD LVCMOS33} [get_ports PS2_dat]
set_property -dict {PACKAGE_PIN Y2  IOSTANDARD LVCMOS33} [get_ports PS2_clk]


create_clock -period 16.667 -name utmi_clk -waveform {0.000 8.333} [get_ports UTMI_clk]
set_output_delay -clock [get_clocks utmi_clk] -min -add_delay 0.000 [get_ports {UTMI_data[*]}]
set_output_delay -clock [get_clocks utmi_clk] -max -add_delay 2.000 [get_ports {UTMI_data[*]}]
set_output_delay -clock [get_clocks utmi_clk] -min -add_delay 0.000 [get_ports UTMI_txvalid]
set_output_delay -clock [get_clocks utmi_clk] -max -add_delay 2.000 [get_ports UTMI_txvalid]

# USB UTMI
set_property -dict {PACKAGE_PIN AF3 IOSTANDARD LVCMOS33}  [get_ports UTMI_chrgvbus]
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33} [get_ports UTMI_clk]
set_property -dict {PACKAGE_PIN AA3 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[0]}]
set_property -dict {PACKAGE_PIN AC3 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[1]}]
set_property -dict {PACKAGE_PIN AE1 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[2]}]
set_property -dict {PACKAGE_PIN AB4 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[3]}]
set_property -dict {PACKAGE_PIN AD3 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[4]}]
set_property -dict {PACKAGE_PIN AA4 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[5]}]
set_property -dict {PACKAGE_PIN AC4 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[6]}]
set_property -dict {PACKAGE_PIN AE2 IOSTANDARD LVCMOS33}  [get_ports {UTMI_data[7]}]
set_property -dict {PACKAGE_PIN AE3 IOSTANDARD LVCMOS33}  [get_ports UTMI_dischrgvbus]
set_property -dict {PACKAGE_PIN AC1 IOSTANDARD LVCMOS33}  [get_ports UTMI_dmpulldown]
set_property -dict {PACKAGE_PIN AC2 IOSTANDARD LVCMOS33}  [get_ports UTMI_dppulldown]
set_property -dict {PACKAGE_PIN AD4 IOSTANDARD LVCMOS33}  [get_ports UTMI_hostdisc]
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33}   [get_ports UTMI_iddig]
set_property -dict {PACKAGE_PIN AD5 IOSTANDARD LVCMOS33}  [get_ports UTMI_idpullup]
set_property -dict {PACKAGE_PIN AA5 IOSTANDARD LVCMOS33}  [get_ports {UTMI_linestate[0]}]
set_property -dict {PACKAGE_PIN AE5 IOSTANDARD LVCMOS33}  [get_ports {UTMI_linestate[1]}]
set_property -dict {PACKAGE_PIN AC6 IOSTANDARD LVCMOS33}  [get_ports {UTMI_opmode[0]}]
set_property -dict {PACKAGE_PIN AF5 IOSTANDARD LVCMOS33}  [get_ports {UTMI_opmode[1]}]
set_property -dict {PACKAGE_PIN AD23 IOSTANDARD LVCMOS33} [get_ports UTMI_reset]
set_property -dict {PACKAGE_PIN AB5 IOSTANDARD LVCMOS33}  [get_ports UTMI_rxactive]
set_property -dict {PACKAGE_PIN AB2 IOSTANDARD LVCMOS33}  [get_ports UTMI_rxerror]
set_property -dict {PACKAGE_PIN AF22 IOSTANDARD LVCMOS33} [get_ports UTMI_rxvalid]
set_property -dict {PACKAGE_PIN AF2 IOSTANDARD LVCMOS33}  [get_ports UTMI_sessend]
set_property -dict {PACKAGE_PIN AE20 IOSTANDARD LVCMOS33} [get_ports UTMI_suspend_n]
set_property -dict {PACKAGE_PIN AE21 IOSTANDARD LVCMOS33} [get_ports UTMI_termsel]
set_property -dict {PACKAGE_PIN AD21 IOSTANDARD LVCMOS33} [get_ports UTMI_txready]
set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVCMOS33} [get_ports UTMI_txvalid]
set_property -dict {PACKAGE_PIN AB1 IOSTANDARD LVCMOS33}  [get_ports UTMI_vbusvalid]
set_property -dict {PACKAGE_PIN AD20 IOSTANDARD LVCMOS33} [get_ports {UTMI_xcvrsel[0]}]
set_property -dict {PACKAGE_PIN AF4 IOSTANDARD LVCMOS33}  [get_ports {UTMI_xcvrsel[1]}]
