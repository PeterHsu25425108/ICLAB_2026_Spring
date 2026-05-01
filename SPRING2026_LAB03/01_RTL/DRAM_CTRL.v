module Sync_FIFO #(
    parameter DATA_WID = 32,
    FIFO_LEN = 8, 
    // MSB is reserved for indicating if the fifo is full
    PTR_WID = 4
)(
    input w_en,
    input pop_en,
    input clk,
    input rst_n,
    input [DATA_WID-1:0] w_data,

    output reg [DATA_WID-1:0] r_data,
    // output [DATA_WID-1:0] peek,
    output full,
    output empty
);

reg [PTR_WID-1:0] w_ptr, r_ptr;
reg [DATA_WID-1:0] fifo [0:FIFO_LEN-1];
integer i;

// assign peek = fifo[r_ptr[PTR_WID-2:0]];
assign empty = &(w_ptr ^~ r_ptr); // (w_ptr == r_ptr)
assign full = (w_ptr[PTR_WID-1] ^ r_ptr[PTR_WID-1]) && 
                &(w_ptr[PTR_WID-2:0] ^~ r_ptr[PTR_WID-2:0]); // (w_ptr[PTR_WID-2:0] == r_ptr[PTR_WID-2:0])

always @(posedge clk or negedge  rst_n) begin
    if(!rst_n)begin
        w_ptr <= 0;
        r_ptr <= 0;
        for(i=0;i<FIFO_LEN;i=i+1)begin
            fifo[i] <= 0;
        end
        r_data <= 0;
    end else begin
        // write
        if(!full && w_en)begin
            w_ptr <= w_ptr + 1;
            fifo[w_ptr[PTR_WID-2:0]] <= w_data;
        end

        // read
        if(!empty && pop_en)begin
            r_ptr <= r_ptr + 1;
            r_data <= fifo[r_ptr[PTR_WID-2:0]];
        end
    end
end

endmodule

// Note:
// 1. valids raise independent of readies, but they have to stay HIGH UNTIL HANDSHAKE OCCURS
// 2. ready signals can wait for valids, but valids cannot wait for readies.
module DRAM_CTRL (
    input               clk,
    input               rst_n,

    // AXI4-Lite slave interface
    // write channel
    // Order: aw_valid <= aw_valid, w_ready
    input [31:0]        aw_addr,
    input               aw_valid,
    output              aw_ready,

    input [63:0]        w_data,
    input               w_valid,
    output              w_ready,

    output wire [1:0]   b_resp,
    output wire         b_valid,
    input               b_ready, // always high

    input [31:0]        ar_addr,
    input               ar_valid,
    output              ar_ready,

    output  [63:0]   r_data,
    output wire [1:0]   r_resp,
    output           r_valid,
    input               r_ready,



    // DRAM master interface
    output reg  [3:0]   dram_cmd,  // {CS_n, RAS_n, CAS_n, WE_n}
    output reg  [1:0]   dram_ba,
    output reg [10:0]  dram_addr,
    output reg [63:0]  dram_wdata, // directly connected to wdata_fifo's rdata so it is a reg output
    input [63:0]        dram_rdata,
    input               dram_valid

);
// dram ctrl commands
parameter NOP = 3'b111;
parameter ACT = 3'b011;
parameter READ = 3'b101;
parameter WRITE = 3'b100;
parameter PRE = 3'b010;

// --- Control regs and wires for the 4 banks --- 

// the state of the axi interface ctrl
reg [1:0] axi_st, nxt_axi_st;
// the nxt dram cmd
reg [3:0] nxt_dram_cmd;

parameter AXI_IDLE = 'd0;
parameter AXI_WRITE = 'd1;
parameter AXI_READ = 'd2;
// parameter AXI_W_WAIT = 'd3; // got aw_addr but w_data_buf is empty or opened_row[req_ba] != req_row, cannot proceed to send write command just yet
// parameter AXI_R_WAIT = 'd4;
// parameter AXI_CHECK_AW = 'd5;
// parameter AXI_CHECK_AR = 'd6;

// the latched aw_addr and ar_addr
wire [15:0] /*aw_buf_wdata, ar_buf_wdata,*/ aw_buf_rdata, ar_buf_rdata;
// the latched w_data
// wire [15:0] peek_aw, peek_ar;

// ctrl signals of the 3 buffers
wire w_en_aw, full_aw, empty_aw;
wire w_en_ar, full_ar, empty_ar;
wire w_en_wdata, full_wdata, empty_wdata;

// indicate if the wdata is available at req_wdata
// this need to be true before issuing a WRITE to dram
// during axi_st == AXI_WRITE, if this is false, we should 
// wait for !empty_wdata before poping one element from fifo_wdata
reg req_wdata_valid;

reg pop_en_ar, pop_en_aw, pop_en_wdata;

// the requested dram addr (selected from aw_addr_buf and ar_addr_buf)
wire [15:0] req_addr;
wire [1:0] req_ba;
wire [5:0] req_row;
wire [7:0] req_col;
wire [63:0] req_wdata;

// wire [15:0] peek_addr;
// wire [1:0] peek_ba;
// wire [5:0] peek_row;
// wire [7:0] peek_col;

// --- Control regs and wires for the 4 banks --- 

// bank state
reg [1:0] ba_st[0:3], nxt_ba_st[0:3];

parameter BA_IDLE = 2'd0;
parameter BA_ACT_ROW = 2'd1; // ACT is issued at the first cycle of this state
parameter BA_OPEN = 2'd2;
parameter BA_PRE = 2'd3; // PRE is issued at the first cycle of this state

// record the opened row of each bank
reg [5:0] opened_row[0:3];
wire [3:0] any_row_opened;

// indicate if the requested addr result in row miss 
// either no rows are opened, or the opened row != req_row
wire [3:0] row_miss;

// counters
reg [2:0] ras_cnt[0:3]; // count t_RAS
reg [2:0] wait_cnt[0:3]; // count other wait times for each state
wire [3:0] can_precharge; // indicate if it has been 5 cycles after ACT is issued

// bank state transition conditions && dram_cmd issue condition
reg send_ACT_nxt, send_PRE_nxt;
reg send_WR_nxt;

// axi state transition conditions


genvar i;
// -----------------------------------------------

// bank state transition conditions && dram_cmd issue condition
always @(*) begin
    send_ACT_nxt = 0;
    send_PRE_nxt = 0;
    send_WR_nxt = 0;

    // send NOP at AXI_IDLE cuz req_addr is yet to be poped
    if(axi_st != AXI_IDLE)begin
        case(ba_st[req_ba])
        BA_OPEN:begin
            if(!row_miss[req_ba]) send_WR_nxt = (axi_st == AXI_READ) ? 1 : req_wdata_valid;
            else if(ras_cnt[req_ba] >= 5) send_PRE_nxt = 1;
        end

        BA_ACT_ROW:begin
            // in reality row_miss[req_ba] should be 1 at this moment
            if(wait_cnt[req_ba]>=2 /*&& !row_miss[req_ba]*/) send_WR_nxt = (axi_st == AXI_READ) ? 1 : req_wdata_valid;
        end

        BA_PRE:begin
            if(wait_cnt[req_ba] >= 3) send_ACT_nxt = 1;
        end

        BA_IDLE:begin
            // activate the row right away
            send_ACT_nxt = 1;
        end

        default:begin
            send_ACT_nxt = 0;
            send_PRE_nxt = 0;
            send_WR_nxt = 0;
        end
        endcase
    end
end

// test signal
// wire w_aw_test;
// assign w_aw_test = w_valid ^ aw_valid;

// axi buffers w_en
assign w_en_ar = ar_valid && !full_ar;
assign w_en_aw = aw_valid && !full_aw /*&& w_ready*/;
assign w_en_wdata = w_valid && !full_wdata;

// req dram addr
assign req_addr = (axi_st == AXI_READ) ? ar_buf_rdata : aw_buf_rdata;
assign req_ba = req_addr[15:14];
assign req_row = req_addr[13:8];
assign req_col = req_addr[7:0];

// ctrl of req_wdata_valid
always @(posedge clk or negedge rst_n) begin : req_wdata_valid_logic
    if(!rst_n)begin
        req_wdata_valid <= 0;
    end else begin
        if(axi_st!= AXI_WRITE && nxt_axi_st == AXI_WRITE)begin
            req_wdata_valid <= !empty_wdata;
        end else if(axi_st == AXI_WRITE)begin
            if(send_WR_nxt)begin
                req_wdata_valid <= !empty_wdata;
            end else begin
                req_wdata_valid <= req_wdata_valid || !empty_wdata;
            end
        end else begin
            req_wdata_valid <= 0;
        end
    end
end

// ==== ar handshake logic ====
// READ command sent <= ar handshake, to ensure the correctness of r_data output order 
assign ar_ready = !full_ar && ar_valid;

// ==== r ch logic =====
assign r_data = dram_rdata;
assign r_valid = dram_valid;
// always @(posedge clk or negedge rst_n) begin : dram_read_outputs
//     if(!rst_n)begin
//         r_valid <= 0;
//         r_data <= 0;
//     end else begin
//         r_valid <= dram_valid;
//         r_data <= dram_valid ? dram_rdata : 0;
//     end
// end

// both response signals are set to OKAY
assign r_resp = 2'b00;
assign b_resp = 2'b00;

// ==== w and aw handshake logic ====
// WRITE command sent <= b valid=1(b handshake), aw_ready=1, ensuring write orders are correct
assign w_ready = !full_wdata && w_valid;
assign aw_ready = !full_aw && aw_valid /*&& w_ready*/;

// ==== b ch logic ========
// raise b_valid at the same cycle as when the write cmd is sent
assign b_valid = (dram_cmd == WRITE);

// ========= FIFOs ========
Sync_FIFO  #(.DATA_WID(64)) wdata_fifo(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(/*w_buf_wdata*/w_data), 
    .r_data(req_wdata),
    .w_en(w_en_wdata),
    .pop_en(pop_en_wdata),
    .full(full_wdata),
    // .peek(),
    .empty(empty_wdata)
);

Sync_FIFO #(.DATA_WID(16)) aw_fifo(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(/*aw_buf_wdata*/aw_addr[15:0]), 
    .r_data(aw_buf_rdata),
    .w_en(w_en_aw),
    .pop_en(pop_en_aw),
    .full(full_aw),
    // .peek(peek_aw),
    .empty(empty_aw)
    
);

Sync_FIFO #(.DATA_WID(16)) ar_fifo(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(/*ar_buf_wdata*/ar_addr[15:0]), 
    .r_data(ar_buf_rdata),
    .w_en(w_en_ar),
    .pop_en(pop_en_ar),
    .full(full_ar),
    // .peek(peek_ar),
    .empty(empty_ar)
);

// dram bank counters and fsm
generate
    for(i=0;i<4;i=i+1)begin : dram_bank_ctrl
        assign any_row_opened[i] = (ba_st[i] == BA_ACT_ROW) || (ba_st[i] == BA_OPEN);
        assign row_miss[i] = !any_row_opened[i] || (opened_row[req_ba] != req_row);
        always @(posedge clk or negedge rst_n) begin : row_ctrl_signals
            if(!rst_n)begin
                opened_row[i] <= 0;
                // any_row_opened[i] <= 0;
            end else begin
                // update opened_row when ACTing it
                if(nxt_ba_st[i] == BA_ACT_ROW)begin
                    opened_row[i] <= req_row;
                    // any_row_opened[i] <= 1;
                // reset any_row_opened when transitioning to PRE
                end else if(nxt_ba_st[i] == BA_PRE) begin
                    // any_row_opened[i] <= 0;
                end
            end
        end

        always @(posedge clk or negedge rst_n) begin : bank_cnt_ctrl
            if(!rst_n)begin
                ras_cnt[i] <= 0;
                wait_cnt[i] <= 0;
            end else begin
                // reset wait_cnt when transitioning into a diff state
                if(ba_st[i] != nxt_ba_st[i]) begin
                    wait_cnt[i] <= 0;
                end else begin
                    // hold if wait_cnt reaches 7
                    wait_cnt[i] <= (&wait_cnt[i]) ? wait_cnt[i] : wait_cnt[i] + 1;
                end

                // reset ras_cnt when transitioning into BA_ACT_ROW
                if(ba_st[i] != BA_ACT_ROW && nxt_ba_st[i] == BA_ACT_ROW)begin
                    ras_cnt[i] <= 0;
                // end else if(ras_cnt[i] < 5) begin
                //     ras_cnt[i] <= ras_cnt[i] + 1;
                end else begin
                    // ras_cnt[i] <= ras_cnt[i];
                    ras_cnt[i] <= &ras_cnt[i] ? ras_cnt[i] : ras_cnt[i] + 1;
                end
            end
        end

        always @(*) begin : nxt_ba_st_logic

            nxt_ba_st[i] = ba_st[i];

            case(ba_st[i])

            // transition to Ba_open BY ITSELF
            BA_ACT_ROW:begin
                if(wait_cnt[i] >= 2) nxt_ba_st[i] = BA_OPEN;
            end

            // 1. stay the same until wait_cnt[i] >= 3
            // 2. if the nxt_dram_cmd == ACT at this moment, transition to BA_ACT_ROW
            // 3. else, transition tp BA_IDLE and wait for ACT command
            BA_PRE:begin
                if(wait_cnt[i] >= 3)begin
                    if(/*nxt_dram_cmd == ACT*/send_ACT_nxt && req_ba == i)begin
                        nxt_ba_st[i] = BA_ACT_ROW;
                    end else begin
                        nxt_ba_st[i] = BA_IDLE;
                    end
                end
            end

            // transition to BA_ACT_ROW when ACT is sent
            BA_IDLE:begin
                if(/*nxt_dram_cmd == ACT*/send_ACT_nxt && req_ba == i) nxt_ba_st[i] = BA_ACT_ROW;
            end

            // stay the same until PRE is sent
            // ras_cnt check should be handled by nxt_dram_ctrl logic
            BA_OPEN:begin
                if(req_ba == i && send_PRE_nxt/*nxt_dram_cmd == PRE*/) nxt_ba_st[i] = BA_PRE;
            end

            // maintain the current state
            default:begin
                nxt_ba_st[i] = ba_st[i];
            end
            endcase
        end

        always @(posedge clk or negedge rst_n) begin : ba_st_seq
            if(!rst_n)begin
                ba_st[i] <= BA_IDLE;
            end else begin
                ba_st[i] <= nxt_ba_st[i];
            end
        end

    end
endgenerate

always @(posedge clk or negedge rst_n) begin : axi_st_seq
    if(!rst_n) begin
        axi_st <= AXI_IDLE;
    end else begin
        axi_st <= nxt_axi_st;
    end
end

always @(*) begin : pop_en_logic
    pop_en_ar = 0;
    pop_en_aw = 0;
    pop_en_wdata = 0;

    case(axi_st)
    AXI_IDLE:begin
        pop_en_ar = !empty_ar;//(nxt_axi_st == AXI_READ);
        pop_en_aw = empty_ar && !empty_aw;//(nxt_axi_st == AXI_WRITE);
        pop_en_wdata = pop_en_aw && !empty_wdata;
    end

    AXI_READ:begin
        // if the current req_addr will be sent & fifo_ar is not empty
        // -> pop from fifo_ar
        pop_en_ar = (!empty_ar && send_WR_nxt);
        // current req_addr will be sent & no more ar_addr to pop && still have aw_addr to pop
        pop_en_aw = (empty_ar && send_WR_nxt && !empty_aw);
        pop_en_wdata = pop_en_aw && !empty_wdata;
    end

    AXI_WRITE:begin
        pop_en_aw = (!empty_aw && send_WR_nxt);
        pop_en_wdata = (!req_wdata_valid && !empty_wdata && !pop_en_aw) || (pop_en_aw && !empty_wdata);
         // current req_addr will be sent & no more aw_addr to pop && still have ar_addr to pop
        pop_en_ar = (empty_aw && send_WR_nxt && !empty_ar);
    end

    default:begin
        pop_en_ar = 0;
    end
    endcase
end
// DO NOT take nxt_dram_cmd or nxt_ba_st as input
always @(*) begin : nxt_axi_state_logic
    nxt_axi_st = axi_st;

    case(axi_st)
    AXI_IDLE:begin
        if(!empty_ar)begin
            nxt_axi_st = AXI_READ;
        end else if(!empty_aw)begin
            nxt_axi_st = AXI_WRITE;
        end
    end

    AXI_READ:begin// Should wait until the last req_addr is issued to dram

        // check if the current req_addr is gonna be issued thru a READ command
        // if so, all reads have been processed at the next cycle, switch to other states
        if(empty_ar && send_WR_nxt)begin
            nxt_axi_st = empty_aw ? AXI_IDLE : AXI_WRITE; 
        end
    end

    AXI_WRITE:begin
        if(empty_aw && send_WR_nxt)begin
            nxt_axi_st = empty_ar ? AXI_IDLE : AXI_READ;
        end
    end

    default:begin
        nxt_axi_st = AXI_IDLE;
    end
    endcase
end

// TODO: rewrite dram_cmd ctrl, nxt_ba_st, wait_cnt control logic 
// so the timing when PRE, ACT, WRITE, READ cmd is sent is clearly defined
// also, nxt_ba_st should referece from dram_cmd cuz we cannot possibly send ACT/PRE to multiple banks
always@(posedge clk or negedge rst_n) begin : dram_cmd_seq
    
    if(!rst_n)begin
        dram_cmd <= NOP;
    end else begin
        dram_cmd <= nxt_dram_cmd;
    end
end

// cannot take nxt_ba_st as input otherwise latch will be synthesized
always @(*) begin : nxt_dram_cmd_logic
    nxt_dram_cmd = NOP;
    if(send_ACT_nxt) nxt_dram_cmd = ACT;
    else if(send_PRE_nxt) nxt_dram_cmd = PRE;
    else if(send_WR_nxt)begin
        if(axi_st == AXI_READ)begin
            nxt_dram_cmd = READ;
        end else if(axi_st == AXI_WRITE)begin
            nxt_dram_cmd = WRITE;
        end
    end

    // req_addr is yet to be poped at AXI_IDLE, leave the dram alone
    // if(axi_st != AXI_IDLE) begin
    //     case(ba_st[req_ba])
    //     BA_IDLE:begin
    //         // send ACT if row_miss occurs
    //         if(row_miss[req_ba]) nxt_dram_cmd = ACT;
    //     end

    //     BA_ACT_ROW:begin
    //         // CAN send write/read if wait_cnt[req_ba] >= 2 (and !row_miss[req_ba]
    //         // tho at this point there shouldn't be row_miss)
    //         if(wait_cnt[req_ba] >= 2 /*&& !row_miss[req_ba]*/) begin
    //             if(nxt_axi_st == AXI_WRITE)begin
    //                 nxt_dram_cmd = WRITE;
    //             end else if(nxt_axi_st == AXI_READ)begin
    //                 nxt_dram_cmd = READ;
    //             end
    //         end
    //     end

    //     BA_OPEN:begin
    //         // CAN send write/read if nxt_axi_st == AXI_WRITE/READ
    //         // send PRE if row_miss[req_ba] && ras_cnt[req_ba] >= 5
    //         if(row_miss[req_ba] && ras_cnt[req_ba] >= 5)begin
    //             nxt_dram_cmd = PRE;
    //         end
    //         else if(nxt_axi_st == AXI_READ)begin
    //             nxt_dram_cmd = READ;
    //         end else if(nxt_axi_st == AXI_WRITE)begin
    //             nxt_dram_cmd = WRITE;
    //         end
    //     end

    //     BA_PRE:begin
    //         // send ACT if wait_cnt[req_ba] >= 3
    //         if(wait_cnt[req_ba] >= 3) begin
    //             nxt_dram_cmd = ACT;
    //         end
    //     end

    //     default:begin
    //         nxt_dram_cmd = NOP;
    //     end
    //     endcase
    // end
end

// dram_addr, dram_ba, dram_wdata
// assign dram_wdata = req_wdata;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dram_ba <= 0;
        dram_addr <= 0;
        dram_wdata <= 0;
    end else begin
        dram_ba <= req_ba;
        dram_wdata <= req_wdata;
        dram_addr <= (nxt_dram_cmd == ACT) ? req_row : req_col;
    end
end

endmodule