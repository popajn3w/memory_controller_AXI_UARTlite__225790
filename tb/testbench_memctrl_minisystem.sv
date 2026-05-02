`include "../rtl/defs_memCtrl.vh"
`timescale 1ns/1ps

module testbench_memctrl_minisystem();

reg  rstn;
reg  clk;
reg  uart_rx;
wire uart_tx;
localparam int BIT_TIME = 4340;    // F_UART=23400Hz ⇔ T=4.340μs

typedef struct {
    logic [3:0] araddr;
    logic arvalid;
    logic arready;
    logic [7:0] rdata;
    logic rvalid;
    logic rready;
    int   status;
    byte  data;
    //reg [3:0] araddr;
    //reg  arvalid;
    //wire arready;
    //wire [7:0] rdata;
    //wire rvalid;
    //reg  rready;
    //int  status;
    //byte data;
} axi_uartlite_trace_t;
axi_uartlite_trace_t trace_rx, trace_tx;

top_minisystem top_minisystem0(
    .clk(clk),
    .rstn(rstn),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
);

axi_uartlite_wrapper axi_uartlite_wrapper_1_trace_rx(
    .s_axi_aclk_0(clk),
    .s_axi_aresetn_0(rstn),
    .UART_0_rxd(uart_rx),
    //.UART_0_txd(uart_tx),    // no connect
    .S_AXI_0_araddr(trace_rx.araddr),
    .S_AXI_0_arready(trace_rx.arready),
    .S_AXI_0_arvalid(trace_rx.arvalid),
    .S_AXI_0_awaddr(0),
    //.S_AXI_0_awready(awready),    // no connect
    .S_AXI_0_awvalid(0),
    .S_AXI_0_bready(0),
    //.S_AXI_0_bresp(bresp),    // no connect
    //.S_AXI_0_bvalid(bvalid),    // no connect
    .S_AXI_0_rdata(trace_rx.rdata),
    .S_AXI_0_rready(trace_rx.rready),
    //.S_AXI_0_rresp(rresp),    // no connect
    .S_AXI_0_rvalid(trace_rx.rvalid),
    .S_AXI_0_wdata(0),
    //.S_AXI_0_wready(wready),    // no connect
    //.S_AXI_0_wstrb(),    // no connect
    .S_AXI_0_wvalid(0)
);

axi_uartlite_wrapper axi_uartlite_wrapper_1_trace_tx(
    .s_axi_aclk_0(clk),
    .s_axi_aresetn_0(rstn),
    .UART_0_rxd(uart_tx),
    //.UART_0_txd(uart_tx),    // no connect
    .S_AXI_0_araddr(trace_tx.araddr),
    .S_AXI_0_arready(trace_tx.arready),
    .S_AXI_0_arvalid(trace_tx.arvalid),
    .S_AXI_0_awaddr(0),
    //.S_AXI_0_awready(awready),    // no connect
    .S_AXI_0_awvalid(0),
    .S_AXI_0_bready(0),
    //.S_AXI_0_bresp(bresp),    // no connect
    //.S_AXI_0_bvalid(bvalid),    // no connect
    .S_AXI_0_rdata(trace_tx.rdata),
    .S_AXI_0_rready(trace_tx.rready),
    //.S_AXI_0_rresp(rresp),    // no connect
    .S_AXI_0_rvalid(trace_tx.rvalid),
    .S_AXI_0_wdata(0),
    //.S_AXI_0_wready(wready),    // no connect
    //.S_AXI_0_wstrb(),    // no connect
    .S_AXI_0_wvalid(0)
);

task automatic uart_send_byte(
    input byte data,
    input int bit_time_ns,
    ref uart_rx
);
    int i;

    // Start bit
    uart_rx = 1'b0;
    #(bit_time_ns);

    // 8 data bits, LSB first
    for (i = 0; i < 8; i++) begin
        uart_rx = data[i];
        #(bit_time_ns);
    end

    // Stop bit
    uart_rx = 1'b1;
    #(bit_time_ns);
endtask

initial begin
    clk = 0;
    #10;  clk = 0;  clk = 1;
    forever begin
        #5 clk = ~clk;
    end
end

initial forever begin
    $timeformat(-6, 2, "us");
    do begin
        // put STATUS reg addr
        trace_rx.arvalid = 0;
        trace_rx.rready  = 0;
        # (BIT_TIME/10);
        trace_rx.araddr  = `STAT_REG_AXI_UART;
        trace_rx.arvalid = 1;
        wait (trace_rx.arready == 1);
        @(posedge clk);
        trace_rx.arvalid = 0;
        // get STATUS reg
        trace_rx.rready = 1;
        wait (trace_rx.rvalid == 1);
        @(posedge clk);
        trace_rx.status = trace_rx.rdata;
        #1 trace_rx.rready = 0;
    end while (trace_rx.status[0] == 0);    // wait while empty
    // put RX_FIFO reg addr
    trace_rx.araddr  = `RX_FIFO_AXI_UART;
    trace_rx.arvalid = 1;
    wait (trace_rx.arready == 1);
    @(posedge clk);
    trace_rx.arvalid = 0;
    // get RX_FIFO
    trace_rx.rready = 1;
    wait (trace_rx.rvalid == 1);
    @(posedge clk);
    trace_rx.data = trace_rx.rdata;
    #1 trace_rx.rready = 0;
    // log
    $display("[time= %0t] uart_rx data= %02h", $time, trace_rx.data);
end
initial forever begin
    $timeformat(-6, 2, "us");
    do begin
        // put STATUS reg addr
        trace_tx.arvalid = 0;
        trace_tx.rready  = 0;
        # (BIT_TIME/10);
        trace_tx.araddr  = `STAT_REG_AXI_UART;
        trace_tx.arvalid = 1;
        wait (trace_tx.arready == 1);
        @(posedge clk);
        trace_tx.arvalid = 0;
        // get STATUS reg
        trace_tx.rready = 1;
        wait (trace_tx.rvalid == 1);
        @(posedge clk);
        trace_tx.status = trace_tx.rdata;
        #1 trace_tx.rready = 0;
    end while (trace_tx.status[0] == 0);    // wait while empty
    // put RX_FIFO reg addr
    trace_tx.araddr  = `RX_FIFO_AXI_UART;
    trace_tx.arvalid = 1;
    wait (trace_tx.arready == 1);
    @(posedge clk);
    trace_tx.arvalid = 0;
    // get RX_FIFO
    trace_tx.rready = 1;
    wait (trace_tx.rvalid == 1);
    @(posedge clk);
    trace_tx.data = trace_tx.rdata;
    #1 trace_tx.rready = 0;
    // log
    $display("[time= %0t] uart_rx data= %02h", $time, trace_tx.data);
end

initial begin
    #1  rstn = 0;  uart_rx = 1;
    #47 rstn = 1;
    #1200 ;
    uart_send_byte(8'hD5, BIT_TIME, uart_rx);
    uart_send_byte(8'h00, BIT_TIME, uart_rx);
    uart_send_byte(8'h01, BIT_TIME, uart_rx);


    $stop();
end

endmodule
