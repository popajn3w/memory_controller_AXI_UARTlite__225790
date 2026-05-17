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
    // TODO init regs & sram used in test prog in rom
    // TODO use sram[5<<7] instead of sram[600]
    // init sram in program code{
    // R0-3 sram addresses, R4-7 values
    dut.rom0.memory[ 0] = {`LOADC,`R0,8'd5};
    dut.rom0.memory[ 1] = {`LOADC,`R4,8'd1};
    dut.rom0.memory[ 2] = {`LOADC,`R1,8'd1};
    dut.rom0.memory[ 3] = {`SHIFTL,`R0,6'd7};     // R0 = 640 = 5<<7
    dut.rom0.memory[ 4] = {`SHIFTL,`R4,6'd31};    // R4 = 0x8000 0000 = 1<<31
    dut.rom0.memory[ 5] = {`LOADC,`R5,8'd10};
    dut.rom0.memory[ 6] = {`LOADC,`R2,8'd2};
    dut.rom0.memory[ 7] = {`LOADC,`R6,8'd20};
    dut.rom0.memory[ 8] = {`STORE,`R0,5'b0,`R4};       // sram[R0] = R4;
    dut.rom0.memory[ 9] = {`STORE,`R1,5'b0,`R5};
    dut.rom0.memory[10] = {`LOADC,`R3,8'd3};
    dut.rom0.memory[11] = {`LOADC,`R7,8'd30};
    dut.rom0.memory[12] = {`LOADC,`R0,8'd4};
    dut.rom0.memory[13] = {`LOADC,`R4,8'd40};
    dut.rom0.memory[14] = {`STORE,`R2,5'b0,`R6};
    dut.rom0.memory[15] = {`STORE,`R3,5'b0,`R7};
    dut.rom0.memory[16] = {`LOADC,`R1,8'd5};
    dut.rom0.memory[17] = {`LOADC,`R5,8'd50};
    dut.rom0.memory[18] = {`LOADC,`R2,8'd6};
    dut.rom0.memory[19] = {`LOADC,`R6,8'd60};
    dut.rom0.memory[20] = {`LOADC,`R3,8'd7};
    dut.rom0.memory[21] = {`LOADC,`R7,8'd0};
    dut.rom0.memory[22] = {`STORE,`R0,5'b0,`R4};
    dut.rom0.memory[23] = {`LOADC,`R0,8'd0};        // sram[0] = program loader addr/code
    dut.rom0.memory[24] = {`LOADC,`R4,8'd1};
    dut.rom0.memory[25] = {`STORE,`R1,5'b0,`R5};
    dut.rom0.memory[26] = {`STORE,`R2,5'b0,`R6};
    dut.rom0.memory[27] = {`STORE,`R3,5'b0,`R7};
    dut.rom0.memory[28] = {`STORE,`R0,5'b0,`R4};    // write program loader addr/code
    dut.rom0.memory[29] = {`NOP};
    // same sram assignments as above, for the simulator
    //dut.sram0.memory[0] = 0;
    //dut.sram0.memory[1] = 10;
    //dut.sram0.memory[2] = 20;
    //dut.sram0.memory[3] = 30;
    //dut.sram0.memory[4] = 40;
    //dut.sram0.memory[5] = 50;
    //dut.sram0.memory[6] = 60;
    //dut.sram0.memory[7] = 0;
    //dut.sram0.memory[640] = 1<<31;
    // }
    // init regs in program code{
    dut.rom0.memory[30] = {`LOADC,`R1,8'd2};
    dut.rom0.memory[31] = {`LOADC,`R2,8'd3};
    dut.rom0.memory[32] = {`LOADC,`R6,8'd5};
    dut.rom0.memory[33] = {`LOADC,`R4,8'b0110_0110};
    dut.rom0.memory[34] = {`LOADC,`R5,8'b1110_1110};
    dut.rom0.memory[35] = {`SHIFTL,`R6,6'd7};    // R6 = 640 = 5<<7
    //dut.rom0.memory[36:49] = {15{`NOP}};
    for (int i = 36; i <= 49; i++)
        dut.rom0.memory[i] = `NOP;
    // alike regs assignments as above, for the simulator
    //dut.core_pipeline0.register_file0.regs[`R0] = 1;
    //dut.core_pipeline0.register_file0.regs[`R1] = 2;
    //dut.core_pipeline0.register_file0.regs[`R2] = 3;
    //dut.core_pipeline0.register_file0.regs[`R3] = 4;
    //dut.core_pipeline0.register_file0.regs[`R4] = 32'b0110_0110_0110_0110_0110_0110_0110_0110;
    //dut.core_pipeline0.register_file0.regs[`R5] = 32'b0111_1110_0110_1110_0111_0110_1110_1110;
    //dut.core_pipeline0.register_file0.regs[`R6] = 600;
    //dut.core_pipeline0.register_file0.regs[`R7] = 0;
    // }



    // ALU instructions {
    dut.rom0.memory[50] = {`SUB,`R0,`R5,`R1};
    dut.rom0.memory[51] = {`NOP};
    dut.rom0.memory[52] = {`NOP};
    dut.rom0.memory[53] = {`NOP};
    dut.rom0.memory[54] = {`ADD,`R0,`R1,`R2};
    dut.rom0.memory[55] = {`NOP};
    dut.rom0.memory[56] = {`NOP};
    dut.rom0.memory[57] = {`NOP};
    dut.rom0.memory[58] = {`SUB,`R3,`R5,`R4};
    dut.rom0.memory[59] = {`NOP};
    dut.rom0.memory[60] = {`NOP};
    dut.rom0.memory[61] = {`NOP};
    dut.rom0.memory[62] = {`AND,`R3,`R4,`R5};
    dut.rom0.memory[63] = {`NOP};
    dut.rom0.memory[64] = {`NOP};
    dut.rom0.memory[65] = {`NOP};
    dut.rom0.memory[66] = {`OR,`R3,`R4,`R5};
    dut.rom0.memory[67] = {`NOP};
    dut.rom0.memory[68] = {`NOP};
    dut.rom0.memory[69] = {`NOP};

    #748
    dut.rom0.memory[70] = {`XOR,`R3,`R4,`R5};
    dut.rom0.memory[71] = {`NOP};
    dut.rom0.memory[72] = {`NOP};
    dut.rom0.memory[73] = {`NOP};
    dut.rom0.memory[74] = {`NXOR,`R3,`R4,`R5};
    dut.rom0.memory[75] = {`NOP};
    dut.rom0.memory[76] = {`NOP};
    dut.rom0.memory[77] = {`NOP};
    dut.rom0.memory[78] = {`SHIFTL,`R2,6'd0};
    dut.rom0.memory[79] = {`NOP};
    dut.rom0.memory[80] = {`NOP};
    dut.rom0.memory[81] = {`NOP};
    dut.rom0.memory[82] = {`SHIFTL,`R2,6'd2};
    dut.rom0.memory[83] = {`NOP};
    dut.rom0.memory[84] = {`NOP};
    dut.rom0.memory[85] = {`NOP};
    dut.rom0.memory[86] = {`SHIFTR,`R2,6'd2};
    dut.rom0.memory[87] = {`NOP};
    dut.rom0.memory[88] = {`NOP};
    dut.rom0.memory[89] = {`NOP};
    // }

    #200 ;    // memory instructions {
    dut.rom0.memory[90] = {`LOAD,`R0,5'b0,`R6};
    dut.rom0.memory[91] = {`NOP};    // data hazard
    dut.rom0.memory[92] = {`NOP};    // src in WB, dest in ID → 2 stall cycles needed
    dut.rom0.memory[93] = {`OR,`R2,`R2,`R0};
    dut.rom0.memory[94] = {`LOADC,`R6,8'd200};
    dut.rom0.memory[95] = {`NOP};
    dut.rom0.memory[96] = {`SHIFTRA,`R2,6'd29};
    dut.rom0.memory[97] = {`NOP};    // data hazard
    dut.rom0.memory[98] = {`NOP};    // src in WB, dest in ID → 2 stall cycles needed
    dut.rom0.memory[99] = {`STORE,`R6,5'd0,`R2};    // M[R6] = R2 = 32'b100
    // }
    // jumps {
    for (int i = 111; i <= 149; i++)
        dut.rom0.memory[i] = `NOP;
    dut.rom0.memory[100] = {`SHIFTR,`R0,6'd31};    // R0 = 1
    dut.rom0.memory[101] = {`LOADC,`R7,8'd150};
    dut.rom0.memory[102] = {`LOADC,`R2,8'd3};    // set R2 as index = b11
    dut.rom0.memory[103] = {`LOADC,`R1,8'd103};    // set R1 as return addr
    dut.rom0.memory[104] = {`JMP,9'b0,`R7};
    dut.rom0.memory[105] = {`NOP};

    #150
    dut.rom0.memory[106] = {`LOADC,`R7,8'd155};
    dut.rom0.memory[107] = {`NOP};
    dut.rom0.memory[108] = {`SHIFTR,`R2,6'd29};   // set R2 as index = b111;
    dut.rom0.memory[109] = {`JMP,9'b0,`R7};
    dut.rom0.memory[110] = {`NOP};

    dut.rom0.memory[120] = {`JMPR,6'b0,-6'd14};
    dut.rom0.memory[140] = {`JMPR,6'b0,-6'd20};

    dut.rom0.memory[150] = {`SUB,`R2,`R2,`R0};    // R2--
    dut.rom0.memory[151] = {`NOP};
    dut.rom0.memory[152] = {`NOP};
    dut.rom0.memory[153] = {`JMPNN,`R2,3'b0,`R1};    // do while(R2>=0)
    dut.rom0.memory[154] = {`JMPR,6'b0,-6'd14};

    dut.rom0.memory[155] = {`SUB,`R2,`R2,`R0};    // R2--
    dut.rom0.memory[156] = {`NOP};
    dut.rom0.memory[157] = {`LOADC,`R7,8'd165};
    dut.rom0.memory[158] = {`JMPRNZ,`R2,6'd2};    // for(i=7;i!=0;i--)  ;
    dut.rom0.memory[159] = {`JMP,9'b0,`R7};

    dut.rom0.memory[160] = {`JMPR,6'b0,-6'd5};
    dut.rom0.memory[161] = {`NOP};
    dut.rom0.memory[162] = {`NOP};
    dut.rom0.memory[163] = {`NOP};
    dut.rom0.memory[164] = {`NOP};
    // }

    //dut.rom0.memory[115] = {`HALT};
    dut.rom0.memory[165] = {`LOADC,`R0,8'd0};    // sum
    dut.rom0.memory[166] = {`LOADC,`R1,8'd0};    // index
    dut.rom0.memory[167] = {`LOADC,`R3,8'd1};    // increment step
    dut.rom0.memory[168] = {`LOADC,`R7,8'd120};
    dut.rom0.memory[169] = {`LOADC,`R6,8'd100};    // upper bound

    dut.rom0.memory[170] = {`SUB,`R2,`R6,`R1};    // cond=100-i;
    dut.rom0.memory[171] = {`ADD,`R0,`R0,`R1};    // sum=sum+i;
    dut.rom0.memory[172] = {`ADD,`R1,`R1,`R3};    // i=i+1;
    dut.rom0.memory[173] = {`JMPRNZ,`R2,-6'd3};
    dut.rom0.memory[174] = {`NOP};
    dut.rom0.memory[175] = {`NOP};
    dut.rom0.memory[176] = {`NOP};    // expected sum == 5050
    dut.rom0.memory[177] = {`LOAD,`R0,5'b0,`R2};
    dut.rom0.memory[178] = {`LOADC,`R1,8'd1};
    dut.rom0.memory[179] = {`LOADC,`R2,8'd2};

    dut.rom0.memory[180] = {`NOP};
    dut.rom0.memory[181] = {`SUB,`R3,`R0,`R1};
    dut.rom0.memory[182] = {`SUB,`R4,`R0,`R2};
    dut.rom0.memory[183] = {`LOADC,`R5,8'd200};
    dut.rom0.memory[184] = {`LOADC,`R6,8'd230};
    dut.rom0.memory[185] = {`JMPRNZ,`R0,6'd2};
    dut.rom0.memory[186] = {`HALT};
    dut.rom0.memory[187] = {`JMPZ,`R3,3'b0,`R5};
    dut.rom0.memory[188] = {`JMPZ,`R4,3'b0,`R6};
    dut.rom0.memory[189] = {`NOP};

    #100 ;    // blinky FPGA test {
    dut.sram0.memory[110] = 3;
    for (int i = 190; i <= 199; i++)
        dut.rom0.memory[i] = `NOP;
    dut.rom0.memory[200] = {`LOADC,`R6,8'd110};    // ARR addr
    dut.rom0.memory[201] = {`LOADC,`R1,8'd1};      // increment step
    dut.rom0.memory[202] = {`LOADC,`R2,8'd0};      // blink register
    dut.rom0.memory[203] = {`LOAD,`R0,5'b0,`R6};   // load ARR
    dut.rom0.memory[204] = {`NOP};
    dut.rom0.memory[205] = {`NOP};
    dut.rom0.memory[206] = {`JMPRZ,`R0,6'd5};    // for(R0=ARR; R0!=0; R0--) ;
    dut.rom0.memory[207] = {`SUB,`R0,`R0,`R1};
    dut.rom0.memory[208] = {`NOP};
    dut.rom0.memory[209] = {`JMPR,6'b0,-6'd4};

    dut.rom0.memory[210] = {`NOP};
    dut.rom0.memory[211] = {`NOP};
    dut.rom0.memory[212] = {`NOP};
    dut.rom0.memory[213] = {`NOP};
    dut.rom0.memory[214] = {`NOP};
    dut.rom0.memory[215] = {`ADD,`R2,`R2,`R1};
    dut.rom0.memory[216] = {`JMPR,6'b0,-6'd13};
    dut.rom0.memory[217] = {`NOP};
    dut.rom0.memory[218] = {`NOP};
    dut.rom0.memory[219] = {`NOP};
    // }

    //$stop();
end

endmodule
