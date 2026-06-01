`include "../RISC_microcoprocessor_599506842/rtl/defs.vh"

module top_minisystem(
    input  clk,
    input  rstn,
    input  uart_rx,
    output uart_tx
);

wire rstn_to_core, halt_to_core;
wire        sram_we_memctrl;
wire [15:0] sram_addr_memctrl;
wire [31:0] sram_din_memctrl;
wire [31:0] sram_dout;
wire        rom_we;
wire [ 9:0] rom_addr;
wire [15:0] rom_din;
wire [15:0] rom_dout;

wire arready, arvalid;
wire [3:0] araddr;
wire rready, rvalid;
wire [31:0] rdata;
wire [ 1:0] rresp;
wire awready, awvalid;
wire [3:0] awaddr;
wire wready, wvalid;
wire [31:0] wdata;
wire bready, bvalid;
wire [1:0] bresp;

wire [`IA_BITS-1 : 0] pc_curr_if;
wire [`I_BITS-1 : 0] instr_rom_id;
wire memRead_ex;
wire memWrite_ex;
wire [`A_BITS-1 : 0] addrRam_ex;
wire [`D_BITS-1 : 0] wr_dataRam_ex;
wire [`D_BITS-1 : 0] dataRam_wb;

axi_uartlite_wrapper axi_uartlite_wrapper_0 (
    .s_axi_aclk_0(clk),
    .s_axi_aresetn_0(rstn),
    .UART_0_rxd(uart_rx),
    .UART_0_txd(uart_tx),
    .S_AXI_0_araddr(araddr),
    .S_AXI_0_arready(arready),
    .S_AXI_0_arvalid(arvalid),
    .S_AXI_0_awaddr(awaddr),
    .S_AXI_0_awready(awready),
    .S_AXI_0_awvalid(awvalid),
    .S_AXI_0_bready(bready),
    .S_AXI_0_bresp(bresp),
    .S_AXI_0_bvalid(bvalid),
    .S_AXI_0_rdata(rdata),
    .S_AXI_0_rready(rready),
    .S_AXI_0_rresp(rresp),
    .S_AXI_0_rvalid(rvalid),
    .S_AXI_0_wdata(wdata),
    .S_AXI_0_wready(wready),
    //.S_AXI_0_wstrb(),    // no connect
    .S_AXI_0_wvalid(wvalid)
);

memCtrl #(
    .sram_addr_width(16),
    .rom_addr_width(10),
    .node_id(0)
) memCtrl0 (
    .clk(clk),
    .rstn(rstn),

    .rstn_to_core(rstn_to_core),
    .halt_to_core(halt_to_core),

    .sram_we(sram_we_memctrl),
    .sram_addr(sram_addr_memctrl),
    .sram_din(sram_din_memctrl),
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

core_pipeline core_pipeline0(
    .rstn(rstn&rstn_to_core),
    .clk(clk),
    .halt_ext(halt_to_core),
    .pc_curr_if(pc_curr_if),
    .instr_rom_id(instr_rom_id),
    .memRead_ex(memRead_ex),
    .memWrite_ex(memWrite_ex),
    .addrRam_ex(addrRam_ex),
    .wr_dataRam_ex(wr_dataRam_ex),
    .dataRam_wb(dataRam_wb)
);

rom #(    // IF/ID stage
    .pc_width(`IA_BITS),
    .instr_width(`I_BITS)
)rom0(
    .clk(clk),
    .we(rom_we),
    .addr(pc_curr_if),
    .addr2(rom_addr),
    .wr_data(rom_din),
    .data(instr_rom_id),
    .data2(rom_dout)
);

sram #(    // EX/WB stage: read+write
    .addr_width(`A_BITS),
    .data_width(`D_BITS)
)sram0(
    .en(memRead_ex|sram_we_memctrl),
    .clk(clk),
    .we(memWrite_ex|sram_we_memctrl),
    .addr((!memWrite_ex&sram_we_memctrl) ? sram_addr_memctrl : addrRam_ex),
    .addr2(sram_addr_memctrl),
    .wr_data((!memWrite_ex&sram_we_memctrl) ? sram_din_memctrl : wr_dataRam_ex),
    .data(dataRam_wb),
    .data2(sram_dout)
);


endmodule
