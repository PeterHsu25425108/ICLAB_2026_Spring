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
    output reg          w_ready,

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
reg [2:0] axi_st, nxt_axi_st;

parameter AXI_IDLE = 'd0;

// tracking whether we are processing read or write request rn
reg is_reading;
// the latched aw_addr and ar_addr
reg [15:0] aw_addr_buf, ar_addr_buf;
// the latched w_data
reg [64:0] w_data_buf;

// the number of elements in the 3 bufs
reg aw_addr_cnt, ar_addr_cnt, w_data_cnt;

// the requested dram addr (selected from aw_addr_buf and ar_addr_buf)
wire [15:0] req_addr;
wire [1:0] req_ba;
wire [5:0] req_row;
wire [7:0] req_col;

// --- Control regs and wires for the 4 banks --- 

// bank state
reg [1:0] ba_st, nxt_ba_st;

parameter BA_INIT = 2'd0;
parameter BA_ACT_ROW = 2'd1; // ACT is issued at the first cycle of this state
parameter BA_OPEN = 2'd2;
parameter BA_PRE = 2'd3; // PRE is issued at the first cycle of this state

// record the opened row of each bank
reg [5:0] opened_row;

// counters
reg [2:0] ras_cnt[0:3]; // count t_RAS
reg [2:0] wait_cnt[0:3]; // count other wait times for each state
wire [3:0] can_precharge; // indicate if it has been 5 cycles after ACT is issued

genvar i;
// -----------------------------------------------

generate
    for(i=0;i<4;i=i+1)begin : dram_bank_ctrl
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                opened_row[i] <= 0;
            end else begin
                // update opened_row when ACTing it
                if(ba_st == BA_ACT_ROW && i == req_ba)begin
                    opened_row[i] <= req_row;
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

                if(ba_st != BA_ACT_ROW && nxt_ba_st == BA_ACT_ROW)begin
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
                
            end
            BA_ACT_ROW:begin
                if(wait_cnt[i] == 1) nxt_ba_st = BA_OPEN;
            end
            BA_PRE:begin
                
            end
            BA_OPEN:begin
                
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

always@(*) begin : dram_interface_ctrl
    
end

// ==== ar handshake logic ====
// READ command sent <= ar handshake, to ensure the correctness of r_data output order 

// both response signals are set to OKAY
assign r_resp = 2'b00;
assign b_resp = 2'b00;

// ==== w and aw handshake logic ====
// WRITE command sent <= b valid=1(b handshake), aw_ready=1, ensuring write orders are correct


endmodule