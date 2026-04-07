module memCtrl_wrapper #(
    parameter sram_addr_width = 16,
    parameter rom_addr_width = 10,
    parameter node_id = 8'd0
)(
    input clk,
    input rstn,
    // core channel
    output rstn_to_core,
    output halt_to_core,
    // memory channel
    output        sram_we,
    output [15:0] sram_addr,
    output [31:0] sram_din,
    input  [31:0] sram_dout,   // flattened from [3:0][7:0]
    output        rom_we,
    output [9:0]  rom_addr,
    output [15:0] rom_din,
    input  [15:0] rom_dout,    // flattened from [1:0][7:0]

    // AXI UARTDRV
    input        arready,
    output       arvalid,
    output [3:0] araddr,

    output       rready,
    input        rvalid,
    input [31:0] rdata,    // extended to DATA_WIDTH==32
    input [1:0]  rresp,

    input         awready,
    input         wready,
    output        awvalid,
    output        wvalid,
    output [3:0]  awaddr,
    output [31:0] wdata,    // extended to DATA_WIDTH==32

    output      bready,
    input       bvalid,
    input [1:0] bresp
);


memCtrl #(
    .sram_addr_width(sram_addr_width),
    .rom_addr_width(rom_addr_width),
    .node_id(node_id)
) memCtrl0 (
    .clk(clk),
    .rstn(rstn),

    .rstn_to_core(rstn_to_core),
    .halt_to_core(halt_to_core),

    .sram_we(sram_we),
    .sram_addr(sram_addr),
    .sram_din(sram_din),
    .sram_dout(sram_dout),

    .rom_we(rom_we),
    .rom_addr(rom_addr),
    .rom_din(rom_din),
    .rom_dout(rom_dout),

    .arready(arready),
    .arvalid(arvalid),
    .araddr(araddr),

    .rready(rready),
    .rvalid(rvalid),
    .rdata(rdata[7:0]),
    .rresp(rresp),

    .awready(awready),
    .wready(wready),
    .awvalid(awvalid),
    .wvalid(wvalid),
    .awaddr(awaddr),
    .wdata(wdata[7:0]),

    .bready(bready),
    .bvalid(bvalid),
    .bresp(bresp)
);

endmodule
