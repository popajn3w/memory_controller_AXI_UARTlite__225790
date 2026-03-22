`define RX_FIFO_AXI_UART 4'h0
`define TX_FIFO_AXI_UART 4'h4
`define STAT_REG_AXI_UART 4'h8
`define CTRL_REG_AXI_UART 4'hC

`define STATUS_OK                         8'd0
`define STATUS_ERR_INCOMPATIBLE_SIZE_TYPE 8'd1
`define STATUS_ERR_UNSUPPORTED_TYPE       8'd2
`define STATUS_ERR_BAD_ADDRESS            8'd3
`define STATUS_ERR_NUM_LOC_0              8'd4
`define STATUS_ERR_CHECKSUM_MISMATCH      8'd5
