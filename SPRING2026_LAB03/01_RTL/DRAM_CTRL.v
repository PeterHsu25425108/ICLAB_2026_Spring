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
// tracking whether we are processing read or write request rn
reg is_reading;
// the latched aw_addr and ar_addr
reg [15:0] aw_addr_buf, ar_addr_buf;
// the latched w_data
reg [64:0] w_data_buf;

// dram ctrl commands
parameter NOP = 3'b111;
parameter ACT = 3'b011;
parameter READ = 3'b101;
parameter WRITE = 3'b100;
parameter PRE = 3'b010;

// the state of dram_ctrl, directly mapping to the current dram_cmd output
reg [2:0] state, nxt_state;
parameter BA_INIT = 2'd0;
parameter BA_ACT_ROW = 2'd1;
parameter BA_OPEN = 2'd2;
parameter BA_PRE = 2'd3;
// --- Control regs and wires for the 4 banks --- 
// bank state
reg [1:0] ba_st, nxt_ba_st;

// counters
reg [2:0] ras_cnt[0:3]; // count t_RAS
reg [2:0] wait_cnt[0:3]; // count other wait times for each state

genvar i;
// -----------------------------------------------

generate
    for(i=0;i<4;i=i+1)begin : dram_bank_ctrl
        always @(posedge clk or negedge rst_n) begin : bank_cnt_ctrl
            if(!rst_n)begin
                ras_cnt[i] <= 0;
                wait_cnt[i] <= 0;
            end else begin
                if(ba_st[i] != nxt_ba_st[i]) begin
                    wait_cnt[i] <= 0;
                end
            end
        end

        always @(*) begin : nxt_ba_st_logic

            nxt_ba_st[i] = ba_st[i];
            case(ba_st[i])
            BA_INIT:begin
                
            end
            BA_ACT_ROW:begin
                
            end
            BA_PRE:begin
                
            end
            BA_OPEN:begin
                
            end
            default:begin
                
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
        state <= NOP;
    end else begin
        state <= nxt_state;
    end
end

always@(posedge clk or negedge rst_n) begin : dram_interface_ctrl
    if(!rst_n) begin
        {dram_ba, dram_addr, dram_wdata} <= 0;
        dram_cmd <= NOP;
    end else begin
        
    end
end

// ==== ar handshake logic ====
// READ command sent <= ar handshake, to ensure the correctness of r_data output order 
assign ar_ready = (nxt_state == READ);


// ==== w and aw handshake logic ====
// WRITE command sent <= b valid=1(b handshake), aw_ready=1, ensuring write orders are correct
assign b_valid = (nxt_state == WRITE);
assign b_resp = 2'b0;
assign aw_ready = (nxt_state == WRITE);


always @(posedge clk or negedge rst_n) begin : read_ch_buffers
    if(!rst_n) begin
        ar_addr_buf <= 0;
    end else begin
        
    end
end

endmodule