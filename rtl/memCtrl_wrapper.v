module memCtrl_wrapper #(
    parameter max_num_locations = 1024,
    parameter node_id = 8'd0
)(
    input clk,
    input rstn,
    // core channel
    output rstn_to_core,
    output halt_to_core,
    // memory channel
    output        sram_we,
    output [9:0]  sram_addr,
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

    output      rready,
    input       rvalid,
    input [7:0] rdata,
    input [1:0] rresp,

    input        awready,
    input        wready,
    output       awvalid,
    output       wvalid,
    output [3:0] awaddr,
    output [7:0] wdata,

    output      bready,
    input       bvalid,
    input [1:0] bresp
);


memCtrl #(
    .max_num_locations(max_num_locations),
    .node_id(node_id)
) dut (
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
    .rdata(rdata),
    .rresp(rresp),

    .awready(awready),
    .wready(wready),
    .awvalid(awvalid),
    .wvalid(wvalid),
    .awaddr(awaddr),
    .wdata(wdata),

    .bready(bready),
    .bvalid(bvalid),
    .bresp(bresp)
);

endmodule
