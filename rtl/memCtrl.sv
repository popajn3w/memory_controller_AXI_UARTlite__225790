`include "defs_memCtrl.vh"

module memCtrl #(
    parameter sram_addr_width = 16,    // max 24 - 1
    parameter rom_addr_width = 10,     // max sram_addr_width
    parameter node_id = 8'd0
)(
    input clk,
    input rstn,
    // core channel
    output reg rstn_to_core,    // comb
    output reg halt_to_core,    // seq
    // memory channel
    output reg        sram_we,
    output reg [15:0] sram_addr,
    output reg [31:0] sram_din,
    input [3:0][ 7:0] sram_dout,
    output reg        rom_we,
    output reg [9:0]  rom_addr,
    output reg [15:0] rom_din,
    input [1:0][ 7:0] rom_dout,

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
    RX_SIZE0, RX_SIZE1, RX_TYPE, RX_ADDR0, RX_ADDR1, RX_ADDR2, RX_DATA,
    RX_NUM_LOC0, RX_NUM_LOC1, RX_FCS,
    ACT_RESET_CPU, ACT_STOP_CPU, ACT_START_CPU,
    ACT_WRITE_MEM, ACT_WRITE_TO_4B_MEM, ACT_WRITE_TO_2B_MEM,
    REQ_TX_STATUS, GET_TX_STATUS, REQ_TX, TX_SFD, TX_DNODE, TX_SNODE,
    TX_SIZE0, TX_SIZE1, TX_TYPE, TX_STATUS, TX_DATA_4B_MEM, TX_DATA_2B_MEM, TX_FCS
} state_t;
state_t state, future_state;
reg [7:0] s_node;
reg [15:0] size;
reg [7:0] cmd_type;
reg [23:0] addr;
reg [7:0] data [0 : 4*(1<<sram_addr_width)-1];
reg [15:0] num_loc;
reg [7:0] fcs_computed;
reg [7:0] cmd_status;
reg [7:0] in32rsh8, in16rsh8;
wire [31:0] out32rsh8;
wire [15:0] out16rsh8;
wire [15:0] size_read =   1   +   (num_loc  <<  (addr[sram_addr_width] ? 2 : 1));
reg [15:0] i;
reg [1:0]  j4;
reg        j2;

always_ff @(posedge clk) begin
    if (!rstn) begin
        halt_to_core <= 0;
        fcs_computed <= 0;
        future_state <= RX_SFD;
        state        <= IDLE;
    end

    else begin
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
                // subtracting ADDR field width, size will represent only data payload width
                size     <= size - 3;
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
                future_state <= RX_ADDR2;
                state        <= REQ_RX_STATUS;
            end
        end
        RX_ADDR2: begin
            if (rvalid) begin
                addr[23:16] <= rdata;
                fcs_computed <= fcs_computed - rdata;
                i            <= 0;
                j4           <= 0;
                j2           <= 0;
                // check address, configure later
                if ({rdata,addr[15:0]} >=0  &&  {rdata,addr[15:0]} < (1<<sram_addr_width+1)-1) begin
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
                future_state <= (i < (size-1)) ? RX_DATA : RX_FCS;
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
                cmd_status    <= ({rdata,num_loc[7:0]} > 0)  ?  `STATUS_OK     :  `STATUS_ERR_NUM_LOC_0;
                future_state  <= ({rdata,num_loc[7:0]} > 0)  ?  RX_FCS         :  TX_SFD;
                state         <= ({rdata,num_loc[7:0]} > 0)  ?  REQ_RX_STATUS  :  REQ_TX_STATUS;
            end
        end
        RX_FCS: begin
            if (rvalid) begin
                future_state <= TX_SFD;
                i            <= 0;
                j4           <= 0;
                j2           <= 0;
                if (rdata == fcs_computed) begin
                    cmd_status <= `STATUS_OK;
                    case (cmd_type)
                        0: state <= ACT_RESET_CPU;
                        1: state <= ACT_STOP_CPU;
                        2: state <= ACT_START_CPU;
                        3: state <= ACT_WRITE_MEM;
                        4: state <= REQ_TX_STATUS;    // read action inside TX_DATA_xB
                    endcase
                end
                else begin
                    cmd_status <= `STATUS_ERR_CHECKSUM_MISMATCH;
                    state      <= REQ_TX_STATUS;
                end
            end
        end

        ACT_RESET_CPU: begin
            i <= i + 1;
            state <= (i<`NUM_CORE_RESET_CYCLES-1) ? state : REQ_TX_STATUS;
        end
        ACT_STOP_CPU: begin
            halt_to_core <= 1;
            state        <= REQ_TX_STATUS;
        end
        ACT_START_CPU: begin
            halt_to_core <= 0;
            state        <= REQ_TX_STATUS;
        end
        // 0 ≤ addr_rom ≤ 1023;  65536 ≤ addr_sram ≤ 65536 + 65536
        ACT_WRITE_MEM: state <= addr[sram_addr_width] ? ACT_WRITE_TO_4B_MEM  : ACT_WRITE_TO_2B_MEM;
        //ACT_WRITE_MEM: state <= addr[sram_addr_width] ? ((i+4<=size) ? ACT_WRITE_TO_4B_MEM
        //                                                : ACT_WRITE_TO_4B_MEM_LAST_BYTES)
        //                                 : ((i+4<=size) ? ACT_WRITE_TO_2B_MEM
        //                                                : ACT_WRITE_TO_2B_MEM_LAST_BYTES);
        //ACT_WRITE_TO_4B_MEM: begin
        //    i <= i + 4;
        //    if (i+8 <= size) begin    // check 1 4B group ahead
        //        // write seq sram_din
        //        sram_addr <= addr;
        //        sram_din <= {data[i+3], data[i+2], data[i+1], data[i]};  // not synth !!
        //    end
        //    else    // if (i+4 == size) → finished
        //        state <= (i+4 == size) ? REQ_TX_STATUS : ACT_WRITE_TO_4B_MEM_LAST_BYTES;
        //end
        ACT_WRITE_TO_4B_MEM: begin
            i  <= i  + 1;
            // 1 extra iteration for last mem combinational transaction
            state <= (i[1:0]==0 && i>=size) ? REQ_TX_STATUS : state;
        end
        ACT_WRITE_TO_2B_MEM: begin
            i  <= i  + 1;
            // 1 extra iteration for last mem combinational transaction
            state <= (i[0]==0 && i>=size) ? REQ_TX_STATUS : state;
        end

        REQ_TX_STATUS: begin
            if (arready)
                state <= GET_TX_STATUS;
        end
        GET_TX_STATUS: begin
            if (rvalid)
                state <= rdata[3] ? REQ_TX_STATUS : REQ_TX;    // advance if not full
        end
        REQ_TX: begin
            if (awready)
                state <= future_state;
        end

        TX_SFD: begin
            future_state <= TX_DNODE;
            if (wready) begin
                fcs_computed <= 0;
                state        <= GET_TX_STATUS;
            end
        end
        TX_DNODE: begin
            future_state <= TX_SNODE;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_SNODE: begin
            future_state <= TX_SIZE0;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_SIZE0: begin
            future_state <= TX_SIZE1;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_SIZE1: begin
            future_state <= TX_TYPE;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_TYPE: begin
            future_state <= TX_STATUS;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_STATUS: begin
            future_state <= (cmd_type!=4) ? TX_FCS
                                          : (addr[sram_addr_width]) ? TX_DATA_4B_MEM : TX_DATA_2B_MEM;
            if (wready) begin
                fcs_computed <= fcs_computed - wdata;
                state        <= GET_TX_STATUS;
            end
        end
        TX_DATA_4B_MEM: begin
            if (wready) begin
                j4           <= j4 + 1;
                i            <= (j4==3) ? i+1 : i;
                fcs_computed <= fcs_computed - sram_dout[j4];
                state        <= (i >= num_loc-1) ? REQ_TX_STATUS : state;
            end
            future_state <= TX_FCS;
        end
        TX_DATA_2B_MEM: begin
            if (wready) begin
                j2           <= j2 + 1;
                i            <= (j2==1) ? i+1 : i;
                fcs_computed <= fcs_computed - rom_dout[j2];
                state        <= (i >= num_loc-1) ? REQ_TX_STATUS : state;
            end
            future_state <= TX_FCS;
        end
        TX_FCS: begin
            future_state <= RX_SFD;
            if (wready)
                state        <= GET_TX_STATUS;
        end
    endcase
    end
end

always_comb begin
    // to avoid latching combinational case blocks, make sure all
    // outputs are written for each iteration
    rstn_to_core = 1;
    arvalid = 0;
    araddr  = 0;
    rready  = 0;
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 0;
    wdata   = 0;
    bready  = 0;
    sram_we   = 0;
    sram_addr = 0;
    sram_din  = 0;
    rom_we    = 0;
    rom_addr  = 0;
    rom_din   = 0;
    in32rsh8 = 0;
    in16rsh8 = 0;
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
        //ACT_WRITE_TO_4B_MEM: begin
        //    // write
        //    sram_addr = addr;
        //    sram_din  = {data[i+3], data[i+2], data[i+1], data[i]};  // not synth !!
        //end
        ACT_WRITE_TO_4B_MEM: begin
            in32rsh8 = (i<size) ? data[i] : 0;
            if(i>0 && i[1:0]==0) begin
                sram_we   = 1;
                sram_addr = addr[sram_addr_width-1 : 0];
                sram_din  = out32rsh8;
            end
        end
        ACT_WRITE_TO_2B_MEM: begin
            in16rsh8 = (i<size) ? data[i] : 0;
            if(i>0 && i[0]==0) begin
                rom_we   = 1;
                rom_addr = addr[rom_addr_width-1 : 0];
                rom_din  = out16rsh8;
            end
        end

        ACT_RESET_CPU: begin
            rstn_to_core = 0;
        end

        REQ_TX_STATUS: begin
            arvalid = 1;
            araddr  = `STAT_REG_AXI_UART;
        end
        GET_TX_STATUS: begin
            rready = 1;
        end
        REQ_TX: begin
            awvalid = 1;
            awaddr  = `TX_FIFO_AXI_UART;
        end

        TX_SFD: begin
            wvalid = 1;
            wdata  = 8'hD5;
        end
        TX_DNODE: begin
            wvalid = 1;
            wdata  = s_node;
        end
        TX_SNODE: begin
            wvalid = 1;
            wdata  = node_id;
        end
        TX_SIZE0: begin
            wvalid = 1;
            case (cmd_type)
                0: wdata = 1;
                1: wdata = 1;
                2: wdata = 1;
                3: wdata = 1;
                4: wdata = size_read[7:0];
                default: wdata = 1;
            endcase
        end
        TX_SIZE1: begin
            wvalid = 1;
            case (cmd_type)
                0: wdata = 0;
                1: wdata = 0;
                2: wdata = 0;
                3: wdata = 0;
                4: wdata = size_read[15:8];
                default: wdata = 0;
            endcase
        end
        TX_TYPE: begin
            wvalid = 1;
            wdata  = cmd_type;
        end
        TX_STATUS: begin
            wvalid = 1;
            wdata  = cmd_status;
        end
        TX_DATA_4B_MEM: begin
            sram_addr = addr[sram_addr_width-1 : 0] + i;
            wvalid  = 1;
            wdata   = sram_dout[j4];
        end
        TX_DATA_2B_MEM: begin
            rom_addr = addr[rom_addr_width-1 : 0] + i;
            wvalid  = 1;
            wdata   = rom_dout[j2];
        end
        TX_FCS: begin
            wvalid = 1;
            wdata  = fcs_computed;
        end
    endcase
end

rshift_k_nbit_reg #(
    .width(32),
    .rshift_bits(8)
) rshift_8_32bit_reg0(
    .en(1),
    .rstn(rstn),
    .clk(clk),
    .d(in32rsh8),
    .q(out32rsh8)
);

rshift_k_nbit_reg #(
    .width(16),
    .rshift_bits(8)
) rshift_8_16bit_reg0(
    .en(1),
    .rstn(rstn),
    .clk(clk),
    .d(in16rsh8),
    .q(out16rsh8)
);

endmodule
