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
    RX_NUM_LOC0, RX_NUM_LOC1, RX_FCS,
    ACT_RESET_CPU, ACT_STOP_CPU, ACT_START_CPU, ACT_WRITE_MEM, ACT_READ_MEM
} state_t;
state_t state, future_state;
reg [7:0] s_node;
reg [7:0] size;
reg [7:0] cmd_type;
reg [15:0] addr;
reg [7:0] data [0 : max_num_locations-1];
reg [15:0] num_loc;
reg [7:0] fcs_computed;
reg [7:0] cmd_status;

always_ff @(posedge clk) begin
    if (!rstn) begin
        arvalid <= 0;
        rready  <= 0;
        awvalid <= 0;
        wvalid  <= 0;
        fcs_computed <= 0;
        future_state <= RX_SFD;
        state        <= IDLE;
    end

    case (state)
        IDLE: begin
            future_state <= RX_SFD;
            state        <= REQ_RX_STATUS;
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
            if (rvalid) begin
                fcs_computed <= 0;
                future_state <= (rdata==8'hD5) ? RX_DNODE : RX_SFD;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_DNODE: begin
            if (rvalid) begin
                fcs_computed <= fcs_computed - rdata;
                // check if we are destination
                future_state <= (rdata==node_id) ? RX_SNODE : RX_SFD;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_SNODE: begin
            if (rvalid) begin
                s_node <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= RX_SIZE0;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_SIZE0: begin
            if (rvalid) begin
                size[7:0] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= RX_SIZE1;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_SIZE1: begin
            if (rvalid) begin
                size[15:8] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= RX_TYPE;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_TYPE:
            if (rvalid) begin
                cmd_type <= rdata;
                fcs_computed <= fcs_computed - rdata;
                case (rdata)    // check for legal size:type pair
                    0: begin
                        cmd_status   <= (size==0) ? `STATUS_OK    : `STATUS_ERR_INCOMPATIBLE_SIZE_TYPE;
                        future_state <= (size==0) ? RX_FCS        : TX_SFD;
                        state        <= (size==0) ? REQ_RX_STATUS : REQ_TX_STATUS;
                    end
                    1: begin
                        cmd_status   <= (size==0) ? `STATUS_OK    : `STATUS_ERR_INCOMPATIBLE_SIZE_TYPE;
                        future_state <= (size==0) ? RX_FCS        : TX_SFD;
                        state        <= (size==0) ? REQ_RX_STATUS : REQ_TX_STATUS;
                    end
                    2: begin
                        cmd_status   <= (size==0) ? `STATUS_OK    : `STATUS_ERR_INCOMPATIBLE_SIZE_TYPE;
                        future_state <= (size==0) ? RX_FCS        : TX_SFD;
                        state        <= (size==0) ? REQ_RX_STATUS : REQ_TX_STATUS;
                    end
                    3: begin
                        cmd_status   <= (size>=3) ? `STATUS_OK    : `STATUS_ERR_INCOMPATIBLE_SIZE_TYPE;
                        future_state <= (size>=3) ? RX_ADDR0      : TX_SFD;
                        state        <= (size>=3) ? REQ_RX_STATUS : REQ_TX_STATUS;
                    end
                    4: begin
                        cmd_status   <= (size==4) ? `STATUS_OK    : `STATUS_ERR_INCOMPATIBLE_SIZE_TYPE;
                        future_state <= (size==4) ? RX_ADDR0      : TX_SFD;
                        state        <= (size==4) ? REQ_RX_STATUS : REQ_TX_STATUS;
                    end
                    default: begin
                        cmd_status   <= `STATUS_ERR_UNSUPPORTED_TYPE;
                        future_state <= TX_SFD;
                        state        <= REQ_TX_STATUS;
                    end
                endcase
            end
        RX_ADDR0: begin
            if (rvalid) begin
                addr[7:0] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= RX_ADDR1;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_ADDR1: begin
            if (rvalid) begin
                addr[15:8] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                i            <= 0;
                // check address, configure later
                if ({rdata,addr[7:0]} >=0  &&  {rdata,addr[7:0]} <10'd1024) begin
                    future_state <= (cmd_type==3) ? RX_DATA : RX_NUM_LOC0;    // else cmd_type==4
                    state        <= REQ_RX_STATUS;
                end
                else begin
                    cmd_status   <= `STATUS_ERR_BAD_ADDRESS;
                    future_state <= TX_SFD;
                    state        <= REQ_TX_STATUS;
                end
            end
        end
        RX_DATA: begin
            if (rvalid) begin
                data[i] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= (i < (size-3)) ? RX_DATA : RX_FCS;
                i            <= i + 1;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_NUM_LOC0: begin
            if (rvalid) begin
                num_loc[7:0] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                future_state <= RX_NUM_LOC1;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_NUM_LOC1: begin
            if (rvalid) begin
                num_loc[15:8] <= rdata;
                fcs_computed  <= fcs_computed - rdata;
                future_state  <= RX_FCS;
                state         <= REQ_RX_STATUS;
            end
        end
        RX_FCS: begin
            if (rvalid) begin
                future_state <= TX_SFD;
                if (rdata == fcs_computed) begin
                    cmd_status <= `STATUS_OK;
                    case (cmd_type)
                        0: state <= ACT_RESET_CPU;
                        1: state <= ACT_STOP_CPU;
                        2: state <= ACT_START_CPU;
                        3: state <= ACT_WRITE_MEM;
                        4: state <= ACT_READ_MEM;
                    endcase
                end
                else begin
                    cmd_status <= `STATUS_ERR_CHECKSUM_MISMATCH;
                    state      <= REQ_TX_STATUS;
                end
            end
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
            rready = 1;
        end
        RX_SNODE: begin
            rready = 1;
        end
        RX_SIZE0: begin
            rready = 1;
        end
        RX_SIZE1: begin
            rready = 1;
        end
        RX_TYPE: begin
            rready = 1;
        end
        RX_ADDR0: begin
            rready = 1;
        end
        RX_ADDR1: begin
            rready = 1;
        end
        RX_DATA: begin
            rready = 1;
        end
        RX_NUM_LOC0: begin
            rready = 1;
        end
        RX_NUM_LOC1: begin
            rready = 1;
        end
        RX_FCS: begin
            rready = 1;
        end
    endcase
end

endmodule
