`include "defs_memCtrl.vh"

module memCtrl #(
    parameter max_num_locations = 1024,    // max (1<<14) - 1
    parameter node_id = 8'd0;
)(
    input clk,
    input rstn,
    // memory channel
    output reg        sram_we,
    output reg [9:0]  sram_addr,
    output reg [31:0] sram_data,
    output reg        rom_we,
    output reg [9:0]  rom_addr,
    output reg [15:0] rom_data,

    // axi uartdrv
    // read channel
    input      arready,
    output reg arvalid,
    output reg [3:0] araddr,

    output reg rready,
    input      rvalid,
    input [7:0] rdata,
    input [1:0] rresp,

    // write channel
    input awready,
    input wready,
    output reg awvalid,
    output reg wvalid,
    output reg [3:0] awaddr,
    output reg [7:0] wdata,

    output reg bready,
    input bvalid,
    input [1:0] bresp
);

typedef enum reg [5:0] {
    IDLE, REQ_RX_STATUS, GET_RX_STATUS, REQ_RX, RX_SFD, RX_DNODE, RX_SNODE,
    RX_SIZE0, RX_SIZE1, RX_TYPE, RX_ADDR0, RX_ADDR1, RX_DATA,
    RX_NUM_LOC0, RX_NUM_LOC1, RX_FCS
} state_t;
state_t state, future_state;
reg [7:0] sfd;
reg [7:0] d_node;
reg [7:0] s_node;
reg [7:0] size;
reg [7:0] cmd_type;
reg [15:0] addr;
reg [7:0] data [0 : max_num_locations-1];
reg [15:0] num_loc;
reg [7:0] fcs;

always_ff @(posedge clk) begin
    if (!rstn) begin
        arvalid <= 0;
        rready  <= 0;
        awvalid <= 0;
        wvalid  <= 0;
        state        <= IDLE;
        future_state <= RX_SFD;
    end

    case (state)
        IDLE: begin
            state        <= REQ_RX_STATUS;
            future_state <= RX_SFD;
        end

        REQ_RX_STATUS: begin
            if (arready)
                state <= GET_RX_STATUS;
        end
        GET_RX_STATUS: begin
            if (rvalid)
                state <= rdata[0] ? REQ_RX : REQ_RX_STATUS;
        end
        REQ_RX: begin
            if (arready)
                state <= future_state;
        end

        RX_SFD: begin
        end
        RX_DNODE: begin
        end
        RX_SNODE: begin
        end
        RX_SIZE0: begin
        end
        RX_SIZE1: begin
        end
        RX_TYPE: begin
        end
        RX_ADDR0: begin
        end
        RX_ADDR1: begin
        end
        RX_DATA: begin
        end
        RX_NUM_LOC0: begin
        end
        RX_NUM_LOC1: begin
        end
        RX_FCS: begin
        end
    endcase
end

always_comb @(*) begin
    // to avoid latching combinational case blocks, make sure all
    // outputs are written for each iteration
    arvalid = 0;
    araddr  = 0;
    rready  = 0;
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 0;
    awdata  = 0;
    bready  = 0;
    case (state)
        IDLE: begin
            arvalid = 0;
            rready  = 0;
            awvalid = 0;
            wvalid  = 0;
        end
        REQ_RX_STATUS: begin
            arvalid = 1;
            araddr  = `STAT_REG_AXI_UART;
        end
        GET_RX_STATUS: begin
            rready = 1;
        end
        REQ_RX: begin
            arvalid = 1;
            araddr  = `RX_FIFO_AXI_UART;
        end
        RX_SFD: begin
            rready = 1;
        end
        RX_DNODE: begin
        end
        RX_SNODE: begin
        end
        RX_SIZE0: begin
        end
        RX_SIZE1: begin
        end
        RX_TYPE: begin
        end
        RX_ADDR0: begin
        end
        RX_ADDR1: begin
        end
        RX_DATA: begin
        end
        RX_NUM_LOC0: begin
        end
        RX_NUM_LOC1: begin
        end
        RX_FCS: begin
        end
    endcase
end

endmodule
