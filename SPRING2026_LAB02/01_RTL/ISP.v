// state assignment
`define IDLE 2'd0
`define GAIN 2'd1
`define IMG 2'd2
`define OUT 2'd3

// Pipeline configuration
`define PRE_STAGES       3  
`define POST_STAGES      2  

// Total cycles of delay required to overlap out_valid with the last in_valid
`define TARGET_LATENCY     255 

// The index of the center pixel in the shift register
`define WIN_CENTER_IDX      (`TARGET_LATENCY - `PRE_STAGES - `POST_STAGES-1) // 249

// Total size of the shift register array (WIN_TOP_LEFT + 1 for 0-based indexing)
`define DPC_REG_CNT    (`WIN_CENTER_IDX + 35) // 285


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
    // input [7:0] count, // determine the polarity of row & col based on the count
    input x_odd,
    input y_odd,
    output [11:0] out
);

reg [6:0] B;

always @(*) begin
    casez({x_odd, y_odd})
    2'b00: B = 7'd64;
    2'b01: B = 7'd48;
    2'b10: B = 7'd52;
    2'b11: B = 7'd72;
    default: B = 7'bx;
    endcase 
end

assign out = (B > in_data) ? 0 : in_data - B;

endmodule

// map pixel coordinate to valid 5x5 window bounds near image edges
module Coor2WinBounds (
    input  [3:0] coord,
    output reg [3:0] pix_lb,
    output reg [3:0] pix_ub
);

always @(*) begin
    case(coord)
        4'd0: begin
            pix_lb = 2;
            pix_ub = 4;
        end
        4'd1: begin
            pix_lb = 1;
            pix_ub = 4;
        end
        4'd14: begin
            pix_lb = 0;
            pix_ub = 3;
        end
        4'd15: begin
            pix_lb = 0;
            pix_ub = 2;
        end
        default: begin
            pix_lb = 0;
            pix_ub = 4;
        end
    endcase
end

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
// reg [1:0] state, nxt_state;

// gain buffers: stores the four corner vals of the gain mesh
// R:3 Gr:2 Gb:1 B:0
reg [11:0] gain_buf [3:0][0:5][0:5]; 

// counter value
wire [7:0] count;

// the coordinate of the pixel being processed on the 16x16 input image
// NOTE: LSC is one stage behind behind the primary input
wire [3:0] x_pix, y_pix;
assign x_pix = count >> 4; // count / 16
assign y_pix = count[3:0]; // count % 16
// ix, iy, dx, dy for gain interpolation
wire [8:0] ix, iy;
wire [7:0] dx, dy;

// counter: MAX count is 255
Counter #(.N(8), .latency(`TARGET_LATENCY)) counter (.clk(clk), .rst_n(rst_n), /*.state(state),*/ .count(count));

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
        if(/*state == `GAIN || state == `IDLE && */param_valid) begin
            // color ch
            for (integer k=0;k<4;k=k+1)begin
                // row
                for(integer i=0;i<6;i=i+1) begin
                    // col
                    for(integer j=0;j<6;j=j+1) begin
                        // the Bottom right cell
                        if(i == 5 && j == 5) gain_buf[k][i][j] <= (k==0) ? param_gain : gain_buf[k-1][0][0];
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
// always @(posedge clk or negedge rst_n) begin : state_transition
//     if(!rst_n) begin
//         state <= `IDLE;
//     end
//     else begin
//         state <= nxt_state;
//     end
// end


// // nxt_state logic
// always@(*) begin : nxt_state_comb
//    case(state)
//     `IDLE: nxt_state = param_valid ? `GAIN : `IDLE;
//     `GAIN: nxt_state = param_valid ? `GAIN : `IMG;
//     `IMG: nxt_state = in_valid ? `IMG : `OUT;
//     `OUT: nxt_state = (count < `TARGET_LATENCY - 1) ? `OUT : `IDLE;
//     default: nxt_state = 2'bx;
//    endcase 
// end

// ===================
// stage 1: BLC
// ===================

// BLC corected input
wire [11:0] BLC_out;
BLC blc(.in_data(in), .out(BLC_out), .x_odd(x_pix[0]), .y_odd(y_pix[0]));

reg [11:0] blc_reg1;
always @(posedge clk or negedge rst_n) begin : BLC_stage1
    // BLC output
    if(!rst_n) begin
        blc_reg1 <= 12'd0;
    end
    else begin
        blc_reg1 <= BLC_out;
    end
end

reg [3:0] x_pix1, y_pix1;
always @(posedge clk or negedge rst_n) begin : x_and_Y_stage1
    if(!rst_n) begin
        x_pix1 <= 0;
        y_pix1 <= 0;
    end
    else begin
        // calculate x_pix1, y_pix1 from the counter val
        x_pix1 <= x_pix; // count / 16
        y_pix1 <= y_pix; // count % 16
    end
end

// =========================================================
// stage 2
// =========================================================

// apply LUT to compute i and d for x and y direction
LSC_weight_calc LUT_x(.coord(x_pix1), .d(dx), .i(ix));
LSC_weight_calc LUT_y(.coord(y_pix1), .d(dy), .i(iy));
// multiply d and i and get 4 the partial products
wire [17:0] ixiy;
wire [15:0] ixdy, dxiy;
wire [14:0] dxdy;
assign ixiy = ix * iy; // 9 bits * 9 bits = 18 bits
assign ixdy = ix * dy; // 9 bits * 8 bits = 16 bits
assign dxiy = dx * iy; // 8 bits * 9 bits = 16 bits
assign dxdy = dx * dy; // max is 171 * 171 = 29241, needs 15 bits

// select the 4 gains from x_pix1 and y_pix1
reg [2:0] x0, y0;
reg [11:0] g00, g01, g10, g11;
reg [1:0] color_ch;
always @(*) begin : gain_select_logic
    casez(x_pix1)
        4'd0, 4'd1, 4'd2: x0 = 0;
        4'd3, 4'd4, 4'd5: x0 = 1;
        4'd6, 4'd7, 4'd8: x0 = 2;
        4'd9, 4'd10, 4'd11: x0 = 3;
        4'd12, 4'd13, 4'd14, 4'd15: x0 = 4;
        default: x0 = 0;
    endcase

    casez(y_pix1)
        4'd0, 4'd1, 4'd2: y0 = 0;
        4'd3, 4'd4, 4'd5: y0 = 1;
        4'd6, 4'd7, 4'd8: y0 = 2;
        4'd9, 4'd10, 4'd11: y0 = 3;
        4'd12, 4'd13, 4'd14, 4'd15: y0 = 4;
        default: y0 = 0;
    endcase

    // Calculate the color ch of the pixel from x_pix1, y_pix1
    color_ch = {x_pix1[0], y_pix1[0]};
    casez({y_pix1[0], x_pix1[0]})
            2'b00: color_ch = 2'd3; // R
            2'b01: color_ch = 2'd2; // Gr
            2'b10: color_ch = 2'd1; // Gb
            2'b11: color_ch = 2'd0; // B
    endcase

    // TODO: confirm the indexing rule of gain_buf and pixel_buf and its correspondence with the input order and their coordinates
    g00 = gain_buf[color_ch][y0][x0];
    g01 = gain_buf[color_ch][y0][x0+1];
    g10 = gain_buf[color_ch][y0+1][x0];
    g11 = gain_buf[color_ch][y0+1][x0+1];
end

reg [3:0] x_pix2, y_pix2;
always @(posedge clk or negedge rst_n) begin : X_and_Y_stage2
    if(!rst_n) begin
        x_pix2 <= 0;
        y_pix2 <= 0;
    end
    else begin
        x_pix2 <= x_pix1;
        y_pix2 <= y_pix1;
    end
end

reg [11:0] g00_reg, g01_reg, g10_reg, g11_reg;
always @(posedge clk or negedge rst_n) begin : gain_stage2
    if(!rst_n) begin
        g00_reg <= 0;
        g01_reg <= 0;
        g10_reg <= 0;
        g11_reg <= 0;
    end
    else begin
        g00_reg <= g00;
        g01_reg <= g01;
        g10_reg <= g10;
        g11_reg <= g11;
    end
end

reg [11:0] blc_reg2;
always @(posedge clk or negedge rst_n) begin : BLC_stage2
    // BLC output
    if(!rst_n) begin
        blc_reg2 <= 12'd0;
    end
    else begin
        blc_reg2 <= blc_reg1;
    end
end

reg [17:0] ixiy2;
reg [15:0] ixdy2, dxiy2;
reg [14:0] dxdy2;
always @(posedge clk or negedge rst_n) begin : i_and_d_stage2
    if(!rst_n) begin
        ixiy2 <= 0;
        ixdy2 <= 0;
        dxiy2 <= 0;
        dxdy2 <= 0;
    end
    else begin
        ixiy2 <= ixiy;
        ixdy2 <= ixdy;
        dxiy2 <= dxiy;
        dxdy2 <= dxdy;
    end
end

// =========================================================
// stage 3
// =========================================================

// multiply the gains to get G(x, y)
// gain: [1024, 2048]
wire [11:0] G_xy;
assign G_xy =  (g00_reg * ixiy2 + g10 * ixdy2 + g01 * dxiy2 + g11 * dxdy2 + 32'd32768) >> 16;

// send P(x, y) to the 3rd stage FFs
reg [11:0] P_xy_reg3;
always @(negedge clk or negedge rst_n) begin : P_xy_stage3
    if(!rst_n) begin
        P_xy_reg3 <= 0;
    end
    else begin
        P_xy_reg3 <= blc_reg2;
    end
end

// send G(x, y) to the 3rd stage FFs
reg [11:0] G_xy_reg3;
always @(negedge clk or negedge rst_n) begin : G_xy_stage3
    if(!rst_n) begin
        G_xy_reg3 <= 0;
    end
    else begin
        G_xy_reg3 <= G_xy;
    end
end

// send the pixel coordinate to the 3rd stage
reg [3:0] x_pix3, y_pix3;
always @(negedge clk or negedge rst_n) begin : X_and_Y_stage3
    if(!rst_n) begin
        x_pix3 <= 0;
        y_pix3 <= 0;
    end
    else begin
        x_pix3 <= x_pix2;
        y_pix3 <= y_pix2;
    end
end

// =========================================================
// stage 4
// =========================================================
wire [13:0] PG_term;
assign PG_term = (P_xy_reg3 * G_xy_reg3 + 22'd512) >> 10;

wire [11:0] Pprime_xy;
assign Pprime_xy = (PG_term > 14'd4095) ? 12'd4095 : PG_term[11:0];

reg Pixel_val4;
always @(posedge clk or negedge rst_n) begin : Pixel_val_stage4
    if(!rst_n) begin
        Pixel_val4 <= 0;
    end
    else begin
        Pixel_val4 <= Pprime_xy;
    end
end

reg [3:0] x_pix4, y_pix4;
always @(negedge clk or negedge rst_n) begin : X_and_Y_stage4
    if(!rst_n) begin
        x_pix4 <= 0;
        y_pix4 <= 0;
    end
    else begin
        x_pix4 <= x_pix3;
        y_pix4 <= y_pix3;
    end
end

// =========================================================
// stage 5: DPC
// =========================================================
reg [3:0] x_pix5, y_pix5;
always @(negedge clk or negedge rst_n) begin : X_and_Y_stage5
    if(!rst_n) begin
        x_pix5 <= 0;
        y_pix5 <= 0;
    end
    else begin
        x_pix5 <= x_pix4;
        y_pix5 <= y_pix4;
    end
end

// DPC shift regs, act as the 4th pipeline reg layer(s)
reg [11:0] pixel_buf[`DPC_REG_CNT-1:0];
always @(negedge clk or negedge rst_n) begin : DPC_shift_reg
    if(!rst_n) begin
        for(integer i = 0; i< `DPC_REG_CNT;i=i+1) pixel_buf[i] <= 0;
    end
    else begin
        // the first reg takes the pixel output from the prev stage
        pixel_buf[0] <= Pixel_val4;
        // the others shift one step forward
        for(integer i = 1; i< `DPC_REG_CNT;i=i+1) begin
            pixel_buf[i] <= pixel_buf[i-1];
        end
    end
end

// the nets we are assigning the window values to, so we can use them for the DPC computation
reg [11:0] DPC_WIN5X5[4:0][4:0];
// the range in where we should assingn pixel_buf value to in DPC_WIN5X5
wire [3:0] winx_pix_lb, winy_pix_ub, winx_pix_ub, winy_pix_lb;

Coor2WinBounds win_bound_x (
    .coord(x_pix4),
    .pix_lb(winx_pix_lb),
    .pix_ub(winx_pix_ub)
);

Coor2WinBounds win_bound_y (
    .coord(y_pix4),
    .pix_lb(winy_pix_lb),
    .pix_ub(winy_pix_ub)
);

// DPC window value logic so we can fix the center of the 5x5 window on pixel_buf[WIN_CENTER_IDX]
always @(*) begin : DPC_window_assign_logic
    // assign the pixel values in the valid region
    for (integer i=0;i<5;i=i+1) begin : pixel_valid_assign
        for(integer j=0;j<5;j=j+1) begin
            if(i >= winy_pix_lb && i <= winy_pix_ub && j >= winx_pix_lb && j <= winx_pix_ub) begin
                // Note: DPC_WIN5X5[y][x], i -> y, j -> x
                DPC_WIN5X5[i][j] = pixel_buf[`WIN_CENTER_IDX + (j-2) - (i-2)*16];
            end
            else begin
                DPC_WIN5X5[i][j] = 0; // default value, will be overwritten in the padding step
            end
        end
    end

    // Step 1: horizontal padding
    // Within the valid y range, clone the vlaues from the valid region to their mirrored counterparts
    // e.g. if winx_pix_lb = 1, winx_pix_ub = 4, then we clone the values in col 2 to col 0
    for (integer i=0;i<5;i=i+1) begin : horizontal_padding
        for(integer j=winy_pix_lb;j<=winy_pix_ub;j=j+1) begin
            if(j < winx_pix_lb) begin
                DPC_WIN5X5[i][j] = DPC_WIN5X5[i][winx_pix_lb + (winx_pix_lb - j)];
            end
            else if(j > winx_pix_ub) begin
                DPC_WIN5X5[i][j] = DPC_WIN5X5[i][winx_pix_ub - (j - winx_pix_ub)];
            end
        end
    end

    // Step 2: Vertical padding
    for (integer j=0;j<5;j=j+1) begin : vertical_padding
        for(integer i=winy_pix_lb;i<=winy_pix_ub;i=i+1) begin
            if(i < winy_pix_lb) begin
                DPC_WIN5X5[i][j] = DPC_WIN5X5[winy_pix_lb + (winy_pix_lb - i)][j];
            end
            else if(i > winy_pix_ub) begin
                DPC_WIN5X5[i][j] = DPC_WIN5X5[winy_pix_ub - (i - winy_pix_ub)][j];
            end
        end
    end
end

// Window values obtained, now perform DPC computations

// find the medians on the 4 directions

// Sum of SAD scores on 4 dirs

// select the median of the dir with min SAD as the target
// tie-breaking: if multiple dir has the min median, priority: H -> V -> D1(UL to BR) -> D2(UR to BL)

// replace the center pixel with the target if |P-target| > 320

// =========================================================
// stage 6
// =========================================================

// Demos

// CCM


// out_valid handling
// always@(*) begin : out_valid_logic
//     out_valid = (state == `OUT) ? 1 : 0;
// end

always @(negedge clk or negedge rst_n) begin : out_reg
    if(!rst_n) begin
        r_out <=0;
        g_out <= 0;
        b_out <= 0;
    end
    else begin
        r_out <=0;
        g_out <= 0;
        b_out <= 0;
    end
end

endmodule