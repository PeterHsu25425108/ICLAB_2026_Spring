// state assignment
`define IDLE 2'd0
`define GAIN 2'd1
`define IMG 2'd2
`define OUT 2'd3

// Pipeline configuration
`define PRE_STAGES       3  // BLC_reg, Partial_Products_reg, pixel_buf[0]
`define POST_STAGES      2  // dpc_reg, output_reg

// Total cycles of delay required to overlap out_valid with the last in_valid
`define TARGET_LATENCY     255 

// The index of the center pixel in the shift register
`define WIN_CENTER       (`TARGET_LATENCY - `PRE_STAGES - `POST_STAGES) // 250

// The index of the oldest pixel (Top-Left corner)
`define WIN_TOP_LEFT     (`WIN_CENTER + 34) // 284

// The index of the newest pixel (Bottom-Right corner)
`define WIN_BOTTOM_RIGHT (`WIN_CENTER - 34) // 216

// Total size of the shift register array (WIN_TOP_LEFT + 1 for 0-based indexing)
`define MAX_REG_COUNT    (`WIN_TOP_LEFT + 1) // 285


// A parameterized counter of arbitary number of bits
module Counter #(parameter N = 4, parameter latency = 5) (
    input clk,
    input rst_n,
    input [1:0] state, // the counter can be reset once reaching certain UB depending on the current state
    output reg [N-1:0] count
);

reg [N-1:0] nxt_val;

always @(*) begin
    casez(state)
        `IDLE: nxt_val = 0;
        `GAIN: nxt_val = (count < 143) ? count + 1 : 0;
        `IMG:  nxt_val = (count < 255) ? count + 1: 0;
        `OUT: nxt_val = (count < latency-1) ? count + 1: 0;
        default: nxt_val = {N{1'bx}};
    endcase
end

always @(posedge clk or negedge rst_n) begin : counter_transistion
    if(!rst_n) begin
       count <= 0;
    end
    else begin
        count <= nxt_val;
    end
end

endmodule

// calculate dx/y, ix/y from x/y coordinate, so we can use them for gain interpolation
module LSC_weight_calc (
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
    input [7:0] count, // determine the polarity of row & col based on the count
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
reg [1:0] state, nxt_state;

// gain buffers: stores the four corner vals of the gain mesh
// R:3 Gr:2 Gb:1 B:0
reg [11:0] gain_buf [3:0][0:5][0:5]; 

reg [11:0] pixel_buf[0:68]; // Stores 4 rows + first 5 cells in the 5th row 
reg [11:0] DPC_win_input[0:4][0:4];

// x, y oftthe pixel located at pixel_buf[34] aka the cente of the DPC window, 
// also denotes the coordinate(16x16) of the cell whose DPC val we are computing for
reg [4:0] win_center_x, win_center_y; 

// counter value
wire [7:0] count;

// counter
Counter #(.N(8), .latency(`TARGET_LATENCY)) counter (.clk(clk), .rst_n(rst_n), .state(state), .count(count));

// gain buffer storage
always @(posedge clk or negedge rst_n) begin : gain_buffer_storage
    if(!rst_n) begin
        for (integer k=0;k<4;k=k+1)begin
                for(integer i=0;i<6;i=i+1) begin
                    for(integer j=0;j<6;j=j+1) begin
                        gain_buf[k][i][j] <= 0;
                    end
                end
        end
    end
    else begin
        if(state == `GAIN) begin
            // color ch
            for (integer k=0;k<4;k=k+1)begin
                // row
                for(integer i=0;i<6;i=i+1) begin
                    // col
                    for(integer j=0;j<6;j=j+1) begin
                        // the Bottom right cell
                        if(i == 5 && j == 5) gain_buf[k][i][j] <= (k==0) ? in : gain_buf[k-1][0][0];
                        // shifting on the same row
                        // i = 0, 1, 2, 3, 4
                        // j = 0, 1, 2, 3
                        else if(j<5) gain_buf[k][i][j] <= gain_buf[k][i][j+1];
                        // shift to the above row
                        // i = 0, 1, 2, 3, 4
                        // j = 5
                        else gain_buf[k][i][j] <= gain_buf[k][i+1][0];
                    end
                end
            end
            
        end
        else begin // hold the value
            for (integer k=0;k<4;k=k+1)begin
                for(integer i=0;i<6;i=i+1) begin
                    for(integer j=0;j<6;j=j+1) begin
                        gain_buf[k][i][j] <= gain_buf[k][i][j];
                    end
                end
            end
        end
    end
end

// state transition logic
always @(posedge clk or negedge rst_n) begin : state_transition
    if(!rst_n) begin
        state <= `IDLE;
    end
    else begin
        state <= nxt_state;
    end
end


// nxt_state logic
always@(*) begin : nxt_state_comb
   case(state)
    `IDLE: nxt_state = param_valid ? `GAIN : `IDLE;
    `GAIN: nxt_state = param_valid ? `GAIN : `IMG;
    `IMG: nxt_state = in_valid ? `IMG : `OUT;
    `OUT: nxt_state = (count < `TARGET_LATENCY - 1) ? `OUT : `IDLE;
    default: nxt_state = 2'bx;
   endcase 
end

// ===================
// stage 1: BLC
// ===================

// BLC corected input
wire [11:0] BLC_out;
BLC blc(.in_data(in), .count(count), .out(BLC_out));

reg [11:0] pipe_reg1;
always @(posedge clk or negedge rst_n) begin : pipe_stage_reg1
    if(!rst_n) begin
        pipe_reg1 <= 12'd0;
    end
    else begin
        pipe_reg1 <= BLC_out;
    end
end

// =========================================================
// stage 2: LSC (Coor mapping ~ multiplication in step 4)
// =========================================================
// the coordinate of the pixel being processed on the 16x16 input image
// NOTE: LSC is one stage behind behind the primary input
wire [3:0] x_pix, y_pix;
// ix, iy, dx, dy for gain interpolation
wire [8:0] ix, iy;
wire [7:0] dx, dy;
// calculate x_pix, y_pix from the counter val
assign x_pix = count >> 4; // count / 16
assign y_pix = count[3:0]; // count % 16
// apply LUT to compute i and d for x and y direction


// =========================================================
// stage 3: LSC (Addition in step 4 ~ )
// =========================================================

// =========================================================
// stage 4: Shift reg + DPC
// =========================================================

// =========================================================
// stage 5: Demos + CCM
// =========================================================

// out_valid handling
always@(*) begin : out_valid_logic
    out_valid = (state == `OUT) ? 1 : 0;
end

endmodule