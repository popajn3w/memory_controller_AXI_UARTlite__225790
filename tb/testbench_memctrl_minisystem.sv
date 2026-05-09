`include "../rtl/defs_memCtrl.vh"
`include "../RISC_microcoprocessor_599506842/rtl/defs.vh"
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

top_minisystem dut(
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

task automatic uart_send_bytes(
    input byte data_q[$],   // queue of bytes
    input int bit_time_ns,
    ref   uart_rx
);
    foreach (data_q[i]) begin
        uart_send_byte(data_q[i], bit_time_ns, uart_rx);
    end
endtask

initial begin
    clk = 0;
    #10;  clk = 0;  clk = 1;
    forever begin
        #5 clk = ~clk;
    end
end

initial forever begin    // logging
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
    $display("[time= %0t] →\t\tuart_rx data= %02h", $time, trace_rx.data);
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
    $display("[time= %0t] ← uart_tx data= %02h", $time, trace_tx.data);
end

initial begin    // main test, memCtrl
    #1  rstn = 0;  uart_rx = 1;
    #47 rstn = 1;
    #1200 ;
    uart_send_bytes({8'hD5,0,1, 0,0, 1, 8'hFE}, BIT_TIME, uart_rx);    // stop
    # 100000 ;
    uart_send_bytes({8'hD5,0,1, 0,0, 2, 8'hFD}, BIT_TIME, uart_rx);    // start
    # 300000 ;
    uart_send_bytes({8'hD5,0,1, 0,0, 0, 8'hFF}, BIT_TIME, uart_rx);    // reset


    $stop();
end

initial begin    // RISC core base test
    dut.sram0.memory[0] = 0;
    dut.sram0.memory[1] = 10;
    dut.sram0.memory[2] = 20;
    dut.sram0.memory[3] = 30;
    dut.sram0.memory[4] = 40;
    dut.sram0.memory[5] = 50;
    dut.sram0.memory[6] = 60;
    dut.sram0.memory[7] = 0;
    dut.sram0.memory[600] = 1<<31;

    // ALU instructions 3 ops {
    //dut.rom0.memory[0] = {`NOP};
    //dut.rom0.memory[1] = {`ADD,`R0,`R1,`R2};
    //dut.rom0.memory[2] = {`SUB,`R3,`R4,`R5};
    //dut.rom0.memory[3] = {`AND,`R3,`R4,`R5};
    //dut.rom0.memory[4] = {`OR,`R3,`R4,`R5};

    dut.rom0.memory[0] = {`SUB,`R0,`R5,`R1};
    dut.rom0.memory[1] = {`NOP};
    dut.rom0.memory[2] = {`NOP};
    dut.rom0.memory[3] = {`NOP};
    dut.rom0.memory[4] = {`ADD,`R0,`R1,`R2};
    dut.rom0.memory[5] = {`NOP};
    dut.rom0.memory[6] = {`NOP};
    dut.rom0.memory[7] = {`NOP};
    dut.rom0.memory[8] = {`SUB,`R3,`R5,`R4};
    dut.rom0.memory[9] = {`NOP};
    dut.rom0.memory[10] = {`NOP};
    dut.rom0.memory[11] = {`NOP};
    dut.rom0.memory[12] = {`AND,`R3,`R4,`R5};
    dut.rom0.memory[13] = {`NOP};
    dut.rom0.memory[14] = {`NOP};
    dut.rom0.memory[15] = {`NOP};
    dut.rom0.memory[16] = {`OR,`R3,`R4,`R5};
    dut.rom0.memory[17] = {`NOP};
    dut.rom0.memory[18] = {`NOP};
    dut.rom0.memory[19] = {`NOP};
    // }

    # 48 ;

    dut.core_pipeline0.register_file0.regs[`R0] = 1;
    dut.core_pipeline0.register_file0.regs[`R1] = 2;
    dut.core_pipeline0.register_file0.regs[`R2] = 3;
    dut.core_pipeline0.register_file0.regs[`R3] = 4;
    dut.core_pipeline0.register_file0.regs[`R4] = 32'b0110_0110_0110_0110_0110_0110_0110_0110;
    dut.core_pipeline0.register_file0.regs[`R5] = 32'b0111_1110_0110_1110_0111_0110_1110_1110;
    dut.core_pipeline0.register_file0.regs[`R6] = 600;
    //dut.core_pipeline0.register_file0.regs[`R7] = 0;

//    dut.rom.memory[100] = ;
//    dut.rom.memory[101] = ;
//    dut.rom.memory[102] = ;
//    dut.rom.memory[103] = ;
//    dut.rom.memory[104] = ;

    #200
    dut.rom0.memory[20] = {`XOR,`R3,`R4,`R5};
    dut.rom0.memory[21] = {`NOP};
    dut.rom0.memory[22] = {`NOP};
    dut.rom0.memory[23] = {`NOP};
    dut.rom0.memory[24] = {`NXOR,`R3,`R4,`R5};
    dut.rom0.memory[25] = {`NOP};
    dut.rom0.memory[26] = {`NOP};
    dut.rom0.memory[27] = {`NOP};
    dut.rom0.memory[28] = {`SHIFTL,`R2,6'd0};
    dut.rom0.memory[29] = {`NOP};
    dut.rom0.memory[30] = {`NOP};
    dut.rom0.memory[31] = {`NOP};
    dut.rom0.memory[32] = {`SHIFTL,`R2,6'd2};
    dut.rom0.memory[33] = {`NOP};
    dut.rom0.memory[34] = {`NOP};
    dut.rom0.memory[35] = {`NOP};
    dut.rom0.memory[36] = {`SHIFTR,`R2,6'd2};
    dut.rom0.memory[37] = {`NOP};
    dut.rom0.memory[38] = {`NOP};
    dut.rom0.memory[39] = {`NOP};

    #200
    dut.rom0.memory[40] = {`LOAD,`R0,5'b0,`R6};
    dut.rom0.memory[41] = {`OR,`R2,`R2,`R0};
    dut.rom0.memory[42] = {`NOP};    // data hazard
    dut.rom0.memory[43] = {`NOP};    // src in WB, dest in ID → 2 stall cycles needed
    dut.rom0.memory[43] = {`SHIFTRA,`R2,6'd1};
    dut.rom0.memory[44] = {`NOP};
    dut.rom0.memory[45] = {`NOP};
    dut.rom0.memory[46] = {`SHIFTRA,`R2,6'd28};
    dut.rom0.memory[47] = {`LOADC,`R6,8'd200};
    dut.rom0.memory[48] = {`NOP};    // data hazard, src in WB, dest in EX → 1 stall cycle
    dut.rom0.memory[49] = {`STORE,`R6,5'd0,`R2};

    dut.rom0.memory[50] = {`SHIFTR,`R0,6'd31};    // R0 = 1
    dut.rom0.memory[51] = {`LOADC,`R7,8'd100};
    dut.rom0.memory[52] = {`LOADC,`R2,8'd3};    // set R2 as index = b11
    dut.rom0.memory[53] = {`LOADC,`R1,8'd53};    // set R1 as return addr
    dut.rom0.memory[54] = {`JMP,9'b0,`R7};
    dut.rom0.memory[55] = {`NOP};

    #150
    dut.rom0.memory[56] = {`LOADC,`R7,8'd105};
    dut.rom0.memory[57] = {`NOP};
    dut.rom0.memory[58] = {`SHIFTR,`R2,6'd29};   // set R2 as index = b111;
    dut.rom0.memory[59] = {`JMP,9'b0,`R7};
    dut.rom0.memory[60] = {`NOP};

    dut.rom0.memory[70] = {`JMPR,6'b0,-6'd14};
    dut.rom0.memory[90] = {`JMPR,6'b0,-6'd20};

    dut.rom0.memory[100] = {`SUB,`R2,`R2,`R0};    // R2--
    dut.rom0.memory[101] = {`NOP};
    dut.rom0.memory[102] = {`NOP};
    dut.rom0.memory[103] = {`JMPNN,`R2,3'b0,`R1};    // do while(R2>=0)
    dut.rom0.memory[104] = {`JMPR,6'b0,-6'd14};

    dut.rom0.memory[105] = {`SUB,`R2,`R2,`R0};
    dut.rom0.memory[106] = {`NOP};
    dut.rom0.memory[107] = {`LOADC,`R7,8'd115};
    dut.rom0.memory[108] = {`JMPRNZ,`R2,6'd2};    // for(i=7;i!=0;i--)  ;
    dut.rom0.memory[109] = {`JMP,9'b0,`R7};

    dut.rom0.memory[110] = {`JMPR,6'b0,-6'd5};
    dut.rom0.memory[111] = {`NOP};
    dut.rom0.memory[112] = {`NOP};
    dut.rom0.memory[113] = {`NOP};
    dut.rom0.memory[114] = {`NOP};

    //dut.rom0.memory[115] = {`HALT};
    dut.rom0.memory[115] = {`LOADC,`R0,8'd0};    // sum
    dut.rom0.memory[116] = {`LOADC,`R1,8'd0};    // index
    dut.rom0.memory[117] = {`LOADC,`R3,8'd1};    // increment step
    dut.rom0.memory[118] = {`LOADC,`R7,8'd120};
    dut.rom0.memory[119] = {`LOADC,`R6,8'd100};    // upper bound

    dut.rom0.memory[120] = {`SUB,`R2,`R6,`R1};    // cond=100-i;
    dut.rom0.memory[121] = {`ADD,`R0,`R0,`R1};    // sum=sum+i;
    dut.rom0.memory[122] = {`ADD,`R1,`R1,`R3};    // i=i+1;
    dut.rom0.memory[123] = {`JMPRNZ,`R2,-6'd3};
    dut.rom0.memory[124] = {`HALT};    // expected sum == 5050
    dut.rom0.memory[125] = {`NOP};
    dut.rom0.memory[126] = {`NOP};
    dut.rom0.memory[127] = {`NOP};
    dut.rom0.memory[128] = {`NOP};
    dut.rom0.memory[129] = {`NOP};

    #50 ;    // 648ns
    //halt = 1;  #10 halt = 0;
    //#40    // 698ns
    //#200 halt = 1;  #74 halt = 0;
    //#30    // 1002ns
    //halt = 1;  #4 halt = 0;
    //#380   // 1386ns
    //halt = 1;  #40 halt = 0;
    //#80    // 1506ns
    //#1500    // 3006ns

    //$stop();
end

endmodule
