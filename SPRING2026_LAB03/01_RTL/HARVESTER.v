module HARVESTER(
    input               clk, 
    input               rst_n,
    input               in_mode_valid,
    input               in_valid,
    input       [1:0]   in_mode,
    input       [1:0]   in_bank,
    input       [5:0]   in_src_row,
    input       [5:0]   in_dst_row,
    input       [63:0]  in_data,
    output reg          out_valid,
    output reg  [63:0]  out_data,
    
    output reg  [31:0]  aw_addr, 
    output reg          aw_valid, 
    input               aw_ready,
    output reg  [63:0]  w_data,  
    output reg          w_valid,  
    input               w_ready,
    input       [1:0]   b_resp,  
    input               b_valid,  
    output              b_ready, // must be ready to recieve b_valid at any time
    output reg  [31:0]  ar_addr, 
    output reg          ar_valid, 
    input               ar_ready,
    input       [63:0]  r_data,  
    input       [1:0]   r_resp, 
    input wire          r_valid, 
    output reg          r_ready
);
// be ready to recieve b_valid at any time
assign b_ready = 1;

reg [1:0] mode;
reg [5:0] src_row;
reg [5:0] dst_row;

// master states
parameter H_IDLE = 'd0;
parameter H_GET_ROW = 'd1; // read in_src_row or in_dst_row
parameter H_READ = 'd2;
parameter H_WRITE = 'd3;
parameter H_CALC = 'd4;
parameter H_SORT = 'd5;

reg [2:0] h_st, nxt_h_st;

// AXI states

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        h_st <= H_IDLE;
    end else begin
        h_st <= nxt_h_st;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mode <= 0;
    end else begin
        mode <= in_mode_valid ? in_mode : mode;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        src_row <= 0;
        dst_row <= 0;
    end else begin
        if(h_st == H_GET_ROW)begin
            if(mode == 0 || mode == 3) src_row <= in_src_row;
            if(mode == 1 || mode == 3) dst_row <= in_dst_row;
        end
    end
end

always @(*) begin : nxt_harvestor_state_logic
    nxt_h_st = h_st;
    case(h_st)
    H_IDLE:begin
        if(in_mode_valid)begin
            nxt_h_st = H_GET_ROW;
        end
    end

    H_GET_ROW:begin
        case(mode)
        2'd0:begin
            nxt_h_st = H_READ;
        end
        2'd1:begin
            nxt_h_st = H_WRITE;
        end
        2'd2:begin
            nxt_h_st = H_CALC;
        end
        2'd3:begin
            nxt_h_st = H_SORT;
        end
        endcase
    end

    
    endcase
end

endmodule
