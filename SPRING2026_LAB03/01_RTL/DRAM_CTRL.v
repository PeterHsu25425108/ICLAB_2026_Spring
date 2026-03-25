// submodule of DRAM_CTRL, maintains the state of a bank

module BankFSM(
    input clk,
    input rst_n,
    input accessed, // whether this bank is being accessed

   
    output reg any_row_open,
    output reg active_row_addr

);

reg [1:0] wait_counter;
reg [2:0] ras_counter[0:3];



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
    output      [3:0]   dram_cmd,  // {CS_n, RAS_n, CAS_n, WE_n}
    output reg  [1:0]   dram_ba,
    output reg  [10:0]  dram_addr,
    output reg  [63:0]  dram_wdata,
    input [63:0]        dram_rdata,
    input               dram_valid

);
// tracking whether we are processing read or write request rn
reg is_reading;
// control the refreshing of latched w_data, aw_addr, ar_addr
wire refresh_addr_w, refresh_addr_r, refresh_data_w;
// the latched aw_addr and ar_addr
reg [15:0] addr_w_latched, addr_r_latched;
// the latched w_data
reg [64:0] data_w_latched;


// the prepared dram interface output for the nxt_cycle
reg [1:0] nxt_dram_ba;
reg [10:0] nxt_dram_addr;

// dram ctrl states
parameter NOP = 3'b111;
parameter ACT = 3'b011;
parameter READ = 3'b101;
parameter WRITE = 3'b100;
parameter PRE = 3'b010;

// indicate if there is a aw_addr without 
// case 1: aw_valid = 1, w_valid = 1

reg lingering_aw_handshake;
// latched aw_addr
reg [15:0] aw_addr_latched, nxt_aw_addr_latched;

// the state of dram_ctrl, directly mapping to the current dram_cmd output
reg [2:0] state, nxt_state;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= NOP;
    end else begin
        state <= nxt_state;
    end
end

assign dram_cmd = {1'b0, state}; // CS_n is always 0 (active)
// TODO: determine how to control nxt dram interface outputs: controled by is_reading selection?
always @(*) begin : nxt_dram_output_logic
    case(nxt_state)
    // ACT: nxt_dram_addr =
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {dram_ba, dram_addr, dram_wdata} <= 0;
    end else begin
        dram_ba <= nxt_dram_ba;
        dram_addr <= nxt_dram_addr;
        dram_wdata <= data_w_latched;
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



always @(*) begin : nxt_aw_addr_latched_logic
    if(aw_addr_wait_w_data) begin
        
    end else begin
        
    end
end

always @(posedge clk or negedge rst_n) begin : aw_addr_latching
    if(!rst_n) begin
        aw_addr_latched <= 0;
    end else begin
        aw_addr_latched <= nxt_aw_addr_latched;
    end
end

endmodule