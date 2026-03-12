// A parameterized counter of arbitary number of bits
// 144 gain val => 256 pixels => DPC latency + pipeline latency
// DPC has to wait until pixel 34 is available => 34(forwarding)/35(without forwarding)
module Counter #(parameter N = 4) (
    input clk,
    input rst_n,
    input [1:0] state, // the counter can be reset once reaching certain UB depending on the current state
    output reg [N-1:0] count
);

always @(posedge clk or negedge rst_n) begin : counter_transistion
    if(!rst_n) begin
       count <= 0;
    end
    else begin
        count <= count + 1;
    end
end

endmodule

// calculate dx/y, ix/y from x/y coordinate, so we can use them for gain interpolation
module weight_calc (
    input  wire [3:0] coord,
    output reg  [7:0] d,
    output reg  [8:0] i
);

    always @(*) begin
        casez (coord)
            4'd0, 4'd3, 4'd6, 4'd9, 4'd12: begin
                d = 8'd0;
                i = 9'd256;
            end
            4'd1, 4'd4, 4'd7, 4'd10, 4'd13: begin
                d = 8'd85;
                i = 9'd171;
            end
            4'd2, 4'd5, 4'd8, 4'd11, 4'd14, 4'd15: begin
                d = 8'd171;
                i = 9'd85;
            end
            default: begin
                d = 8'dx;
                i = 9'dx;
            end
        endcase
    end

endmodule

module BLC(
    input [11:0] in_data,
    // input [] count, // determine the polarity of row & col based on the count
    output [11:0] out
);

endmodule

module ISP(
    //Input Port
    clk,
    rst_n,

    in_valid,
    in,
    param_valid,
    param_gain,

    //Output Port
    out_valid,
    r_out,
    g_out,
    b_out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_valid;
input [11:0] in;
input param_valid;
input [11:0] param_gain;

output reg out_valid;
output reg [11:0] r_out;
output reg [11:0] g_out;
output reg [11:0] b_out;

//==============================
//   Design
//==============================
// state
parameter IDLE = 2'd0;
parameter GAIN = 2'd1;
parameter IMG = 2'd2;
parameter OUT = 2'd3;
reg [1:0] state, nxt_state;

// gain buffers
reg [11:0] gain_buf [0:5][0:5]; // stores the four corner vals of the gain mesh

reg [11:0] pixel_buf[0:68]; // Stores 4 rows + first 5 cells in the 5th row 
reg [11:0] DPC_win_input[0:4][0:4];

// x, y oftthe pixel located at pixel_buf[34] aka the cente of the DPC window, 
// also denotes the coordinate(16x16) of the cell whose DPC val we are computing for
reg [4:0] win_center_x, win_center_y; 

// gain buffer storage
always @(posedge clk or negedge rst_n) begin : gain_buffer_storage
    if(!rst_n) begin
        for(integer i=0;i<6;i=i+1) begin
            for(integer j=0;j<6;j=j+1) begin
                gain_buf[i][j] <= 0;
            end
        end
    end
    else begin
        if(state == GAIN) begin
            for(integer i=0;i<6;i=i+1) begin
                for(integer j=0;j<6;j=j+1) begin
                    if(j<5)begin
                        gain_buf[i][j] <= gain_buf[i][j+1]; // shift by row-dominant order
                    end
                    else begin // end of a row
                        if(i==5) gain_buf[i][j] <= in; // for gain_buf[5][5], insert the input
                        else gain_buf[i][j] <= gain_buf[i+1][j]; // shift by row-dominant order
                    end
                end
            end
        end
        else begin // hold the value
            for(integer i=0;i<6;i=i+1) begin
                for(integer j=0;j<6;j=j+1) begin
                    gain_buf[i][j] <= gain_buf[i][j];
                end
            end
        end
    end
end

// state transition logic
always @(posedge clk or negedge rst_n) begin : state_transition
    if(!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= nxt_state;
    end
end
// nxt_state logic
always@(*) begin : nxt_state_comb
   case(state)
    // IDLE: nxt_state = 
    // GAIN: nxt_state = 
    // IMG: nxt_state = 
    // OUT: nxt_state = 
    default: nxt_state = 2'bx;
   endcase 
end

endmodule