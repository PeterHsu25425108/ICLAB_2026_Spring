module Sync_FIFO #(
    parameter DATA_WID = 32,
    FIFO_LEN = 8, 
    // MSB is reserved for indicating if the fifo is full
    PTR_WID = 4
)(
    input w_en,
    input r_en,
    input clk,
    input rst_n,
    input [DATA_WID-1:0] w_data,

    output reg [DATA_WID-1:0] r_data,
    output full,
    output empty
);

reg [PTR_WID-1:0] w_ptr, r_ptr;
reg [DATA_WID-1:0] fifo [0:FIFO_LEN-1];
integer i;

always @(posedge clk or negedge  rst_n) begin
    if(!rst_n)begin
        w_ptr <= 0;
        r_ptr <= 0;
        for(i=0;i<FIFO_LEN;i=i+1)begin
            fifo[i] <= 0;
        end
    end else begin
        // write
        if(!full && w_en)begin
            w_ptr <= w_ptr + 1;
            fifo[w_ptr[PTR_WID-2:0]] <= w_data;
        end

        // read
        if(!empty && r_en)begin
            r_ptr <= r_ptr + 1;
            r_data <= fifo[r_ptr[PTR_WID-2:0]];
        end
    end
end

assign empty = &(w_ptr ^~ r_ptr); // (w_ptr == r_ptr)
assign full = (w_ptr[PTR_WID-1] ^ r_ptr[PTR_WID-1]) && 
                &(w_ptr[PTR_WID-2:0] ^~ r_ptr[PTR_WID-2:0]); // (w_ptr[PTR_WID-2:0] == r_ptr[PTR_WID-2:0])

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

    output reg [63:0]   r_data,
    output wire [1:0]   r_resp,
    output reg          r_valid,
    input               r_ready,



    // DRAM master interface
    output reg  [3:0]   dram_cmd,  // {CS_n, RAS_n, CAS_n, WE_n}
    output reg  [1:0]   dram_ba,
    output reg  [10:0]  dram_addr,
    output reg  [63:0]  dram_wdata,
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

parameter AXI_IDLE = 'd0;
parameter AXI_WRITE = 'd1;
parameter AXI_READ = 'd2;
parameter AXI_WAIT_WDATA = 'd3; // got aw_addr but w_data_buf is empty, cannot proceed to send write command just yet

// the latched aw_addr and ar_addr
wire [15:0] aw_buf_wdata, ar_buf_wdata, aw_buf_rdata, ar_buf_rdata;
// the latched w_data
wire [63:0] w_buf_wdata, w_buf_rdata;

// ctrl signals of the 3 buffers
wire w_en_aw, r_en_aw, full_aw, empty_aw;
wire w_en_ar, r_en_ar, full_ar, empty_ar;
wire w_en_wdata, r_en_wdata, full_wdata, empty_wdata;

// the requested dram addr (selected from aw_addr_buf and ar_addr_buf)
wire [15:0] req_addr;
wire [1:0] req_ba;
wire [5:0] req_row;
wire [7:0] req_col;

// --- Control regs and wires for the 4 banks --- 

// bank state
reg [1:0] ba_st[0:3], nxt_ba_st[0:3];

parameter BA_INIT = 2'd0;
parameter BA_ACT_ROW = 2'd1; // ACT is issued at the first cycle of this state
parameter BA_OPEN = 2'd2;
parameter BA_PRE = 2'd3; // PRE is issued at the first cycle of this state

// record the opened row of each bank
reg [5:0] opened_row[0:3];
reg [3:0] any_row_opened;

// counters
reg [2:0] ras_cnt[0:3]; // count t_RAS
reg [2:0] wait_cnt[0:3]; // count other wait times for each state
wire [3:0] can_precharge; // indicate if it has been 5 cycles after ACT is issued

genvar i;
// -----------------------------------------------

// axi buffers
assign w_en_ar = ar_valid && !full_ar;
assign w_en_aw = aw_valid && !full_aw;
assign w_en_wdata = w_valid && !full_wdata;
assign r_en_ar = (nxt_axi_st == READ);
assign r_en_aw = (nxt_axi_st == WRITE);
assign r_en_wdata = (nxt_axi_st == WRITE);

// req dram addr
assign req_addr = (axi_st == READ) ? ar_buf_rdata : aw_buf_rdata;
assign req_ba = req_addr[15:14];
assign req_row = req_addr[13:8];
assign req_col = req_addr[7:0];


// ==== ar handshake logic ====
// READ command sent <= ar handshake, to ensure the correctness of r_data output order 
assign ar_ready = !full_ar && ar_valid;

// ==== r ch logic =====
always @(posedge clk or negedge rst_n) begin : dram_read_outputs
    if(!rst_n)begin
        r_valid <= 0;
        r_data <= 0;
    end else begin
        r_valid <= dram_valid;
        r_data <= dram_valid ? dram_rdata : 0;
    end
end

// both response signals are set to OKAY
assign r_resp = 2'b00;
assign b_resp = 2'b00;

// ==== w and aw handshake logic ====
// WRITE command sent <= b valid=1(b handshake), aw_ready=1, ensuring write orders are correct
assign w_ready = !full_wdata && w_valid;
assign aw_ready = !full_aw && aw_valid;

// ==== b ch logic ========
assign b_valid = axi_st == AXI_WRITE;

// ========= FIFOs ========
Sync_FIFO  #(.DATA_WID(64)) w_buf(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(w_buf_wdata), 
    .r_data(w_buf_rdata),
    .w_en(w_en_wdata),
    .r_en(r_en_wdata),
    .full(full_wdata),
    .empty(empty_wdata)
);

Sync_FIFO #(.DATA_WID(16)) aw_buf(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(aw_buf_wdata), 
    .r_data(aw_buf_rdata),
    .w_en(w_en_aw),
    .r_en(r_en_aw),
    .full(full_aw),
    .empty(empty_aw)
);

Sync_FIFO #(.DATA_WID(16)) ar_buf(
    .clk(clk), 
    .rst_n(rst_n), 
    .w_data(ar_buf_wdata), 
    .r_data(ar_buf_rdata),
    .w_en(w_en_ar),
    .r_en(r_en_ar),
    .full(full_ar),
    .empty(empty_ar)
);

// dram bank counters and fsm
generate
    for(i=0;i<4;i=i+1)begin : dram_bank_ctrl
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                opened_row[i] <= 0;
                any_row_opened[i] <= 0;
            end else begin
                // update opened_row when ACTing it
                if(ba_st[i] == BA_ACT_ROW)begin
                    opened_row[i] <= req_row;
                    any_row_opened[i] <= 1;
                // reset any_row_opened when transitioning to PRE
                end else if(nxt_ba_st[i] == BA_PRE) begin
                    any_row_opened[i] <= 0;
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
                    wait_cnt[i] <= wait_cnt[i] + 1;
                end

                if(ba_st[i] != BA_ACT_ROW && nxt_ba_st[i] == BA_ACT_ROW)begin
                    // reset ras_cnt when transitioning into BA_ACT_ROW
                    ras_cnt[i] <= 0;
                end else if(ras_cnt[i] < 4) begin
                    ras_cnt[i] <= ras_cnt[i] + 1;
                end else begin
                    ras_cnt[i] <= ras_cnt[i];
                end
            end
        end

        always @(*) begin : nxt_ba_st_logic

            nxt_ba_st[i] = ba_st[i];

            case(ba_st[i])
            BA_INIT:begin
                // transisition when !empty_ar or !empty_aw?
                if((axi_st == READ || axi_st == WRITE) && req_ba == i) nxt_ba_st[i] = BA_ACT_ROW;
            end
            BA_ACT_ROW:begin
                if(wait_cnt[i] == 1) nxt_ba_st[i] = BA_OPEN;
            end
            BA_PRE:begin
                if(wait_cnt[i]==2 && ras_cnt[i] == 4) nxt_ba_st[i] = BA_ACT_ROW;
            end
            BA_OPEN:begin
                if(req_ba == i && req_row != opened_row[i])begin
                    nxt_ba_st[i] = BA_PRE;
                end
            end
            // maintain the current state
            default:begin
                nxt_ba_st[i] = ba_st[i];
            end
            endcase
        end

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                ba_st[i] <= BA_INIT;
            end else begin
                ba_st[i] <= nxt_ba_st[i];
            end
        end

    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_st <= NOP;
    end else begin
        axi_st <= nxt_axi_st;
    end
end

always @(*) begin : nxt_axi_state
    nxt_axi_st = axi_st;
    case(axi_st)
    AXI_IDLE:begin
        if(!empty_ar)begin
            nxt_axi_st = AXI_READ;
        end else if(!empty_aw)begin
            if(!empty_wdata)begin
                // switch to the write mode
                nxt_axi_st = AXI_WRITE;
            end else begin
                // need to wait for the wdata
                nxt_axi_st = AXI_WAIT_WDATA;
            end
        end
    end

    AXI_READ:begin
        if(empty_ar) nxt_axi_st = AXI_IDLE;
    end

    AXI_WAIT_WDATA:begin
        if(!empty_wdata) nxt_axi_st = AXI_WRITE;
    end

    AXI_WRITE:begin
        if(empty_aw)begin
            nxt_axi_st = AXI_IDLE;
        end else if(empty_wdata)begin
            nxt_axi_st = AXI_WAIT_WDATA;
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
always@(*) begin : dram_cmd_ctrl
    // dram cmd
    dram_cmd = NOP;
    case(axi_st)
    AXI_WRITE:begin
        if(ba_st[req_ba] == BA_OPEN)begin
            dram_cmd = (req_row != opened_row[req_ba]) ? PRE : WRITE;
        end else if(ba_st[req_ba] == ACT) begin
            // dram_cmd = (wait_cnt[req_ba] == 1) ? 
        end else if(ba_st[req_ba] == PRE)begin
            // dram_cmd = 
        end
    end
    AXI_READ:begin
        if(ba_st[req_ba] == BA_OPEN)begin
            dram_cmd = (req_row != opened_row[req_ba]) ? PRE : READ;
        end
    end
    AXI_WAIT_WDATA:begin
        
    end

    default:begin
        dram_cmd = NOP;
    end
    endcase
end


endmodule