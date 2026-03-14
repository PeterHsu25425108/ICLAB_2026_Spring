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
`define DPC_REG_CNT    (`WIN_CENTER_IDX + 35) // 284

// The exact delay tap for the valid signal to align with WIN_CENTER_IDX
`define VALID_TAP_IDX       (`TARGET_LATENCY - `POST_STAGES) // 253


// A parameterized counter of arbitary number of bits
module Counter #(parameter N = 4, parameter latency = 5) (
    input clk,
    input rst_n,
    // input [1:0] state, // the counter can be reset once reaching certain UB depending on the current state
    input in_valid,
    input param_valid,
    // output reg out_valid,
    output reg [N-1:0] count
);
// wire active;
reg [N-1:0] nxt_count;
// reg nxt_out_valid;

// always @(*) begin : nxt_count_logic
//     nxt_count = active ? (count + 1) : 0;
// end

// always @(*) begin : nxt_out_valid_logic
//     nxt_out_valid = active & (&count ^ ~in_valid);
// end

// assign active = in_valid | out_valid;

always @(posedge clk or negedge rst_n) begin : counter_transistion
    if(!rst_n) begin
       count <= 0;
    //    out_valid <= 0;
    end
    else if (in_valid) begin
        count <= count + 1;
    end
    else begin
        count <= 0; // Automatically resets for the next frame
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
    input in_valid,
    output [11:0] out
);

reg [6:0] B;

always @(*) begin
    casez({y_odd, x_odd})
    2'b00: B = 7'd64;
    2'b01: B = 7'd48;
    2'b10: B = 7'd52;
    2'b11: B = 7'd72;
    default: B = 7'bx;
    endcase 
end

assign out = in_valid ? ((B > in_data) ? 0 : in_data - B) : 0;

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

// a 12 bit CAS
module CAS12(
    input [11:0] a,
    input [11:0] b,
    output [11:0] bigVal,
    output [11:0] smallVal
);
wire a_big = (a > b) ? 1'b1 : 1'b0;
assign bigVal = a_big ? a : b;
assign smallVal = a_big ? b : a;

endmodule

// a 12 bit 4 element sorter
module Sorter4(
    input [11:0] in0,
    input [11:0] in1,
    input [11:0] in2,
    input [11:0] in3,
    output [11:0] out0, // smallest
    output [11:0] out1,
    output [11:0] out2,
    output [11:0] out3  // biggest
);

    wire [11:0] cas01_big, cas01_small;
    CAS12 cas01(.a(in0), .b(in1), .bigVal(cas01_big), .smallVal(cas01_small));
    wire [11:0] cas23_big, cas23_small;
    CAS12 cas23(.a(in2), .b(in3), .bigVal(cas23_big), .smallVal(cas23_small));
    wire [11:0] cas02_big, cas02_small;
    CAS12 cas02(.a(cas01_small), .b(cas23_small), .bigVal(cas02_big), .smallVal(cas02_small));
    wire [11:0] cas13_big, cas13_small;
    CAS12 cas13(.a(cas01_big), .b(cas23_big), .bigVal(cas13_big), .smallVal(cas13_small));
    wire [11:0] cas12_big, cas12_small;
    CAS12 cas12(.a(cas02_big), .b(cas13_small), .bigVal(cas12_big), .smallVal(cas12_small));
    assign out0 = cas02_small;
    assign out1 = cas12_small;
    assign out2 = cas12_big;
    assign out3 = cas13_big;
endmodule

module DemosMod(
    input [11:0] NW,
    input [11:0] NE,
    input [11:0] SW,
    input [11:0] SE,
    input [11:0] N,
    input [11:0] S,
    input [11:0] W,
    input [11:0] E,
    input [11:0] C, // center
    input [3:0] x,
    input [3:0] y,
    output reg [11:0] Rout,
    output reg [11:0] Gout,
    output reg [11:0] Bout
);

// shared adders to compute interpolations
wire [11:0] br_inter_hv, br_inter_diag, g_inter_h, g_inter_v;
assign br_inter_hv = (N+S+E+W) >> 2;
assign br_inter_diag = (NW+NE+SW+SE) >> 2;
assign g_inter_h = (E + W) >> 1;
assign g_inter_v = (N + S) >> 1;

// R & B loc share the same logic
wire x_even, y_even;
assign x_even = x[0];
assign y_even = y[0];

// send the interpolation outputs to the correct channel
always @(*) begin : Demos_interpolation_assign
    casez({y_even, x_even})
        2'b00:begin// R loc
            Rout = C;
            Bout = br_inter_diag;
            Gout = br_inter_hv;
        end
        2'b01:begin // G on R row
            Rout = g_inter_h;
            Bout = g_inter_v;
            Gout = C;
        end
        2'b10:begin // G on B row
            Rout = g_inter_v;
            Bout = g_inter_h;
            Gout = C;
        end
        2'b11:begin // B loc
            Rout = br_inter_diag;
            Bout = C;
            Gout = br_inter_hv;
        end
        default: begin
            Rout = 12'bx;
            Bout = 12'bx;
            Gout = 12'bx;
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
assign y_pix = count >> 4; // count / 16
assign x_pix = count[3:0]; // count % 16
// ix, iy, dx, dy for gain interpolation
wire [8:0] ix, iy;
wire [7:0] dx, dy;

// counter: MAX count is 255
Counter #(.N(8), .latency(`TARGET_LATENCY)) counter (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .param_valid(param_valid),
    // .out_valid(out_valid),
    .count(count)
);


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
                        if(i == 5 && j == 5) gain_buf[k][i][j] <= (k==0) ? (param_valid ? param_gain : 0) : gain_buf[k-1][0][0];
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

// // state transition logic
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
BLC blc(.in_data(in), .out(BLC_out), .x_odd(x_pix[0]), .y_odd(y_pix[0]), .in_valid(in_valid));

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
assign G_xy =  (g00_reg * ixiy2 + g10_reg * ixdy2 + g01_reg * dxiy2 + g11_reg * dxdy2 + 32'd32768) >> 16;

// send P(x, y) to the 3rd stage FFs
reg [11:0] P_xy_reg3;
always @(posedge clk or negedge rst_n) begin : P_xy_stage3
    if(!rst_n) begin
        P_xy_reg3 <= 0;
    end
    else begin
        P_xy_reg3 <= blc_reg2;
    end
end

// send G(x, y) to the 3rd stage FFs
reg [11:0] G_xy_reg3;
always @(posedge clk or negedge rst_n) begin : G_xy_stage3
    if(!rst_n) begin
        G_xy_reg3 <= 0;
    end
    else begin
        G_xy_reg3 <= G_xy;
    end
end

// send the pixel coordinate to the 3rd stage
reg [3:0] x_pix3, y_pix3;
always @(posedge clk or negedge rst_n) begin : X_and_Y_stage3
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
assign PG_term = (P_xy_reg3 * G_xy_reg3 + 24'd512) >> 10;

wire [11:0] Pprime_xy;
assign Pprime_xy = (PG_term > 14'd4095) ? 12'd4095 : PG_term[11:0];

// reg Pixel_val4;
// always @(posedge clk or negedge rst_n) begin : Pixel_val_stage4
//     if(!rst_n) begin
//         Pixel_val4 <= 0;
//     end
//     else begin
//         Pixel_val4 <= Pprime_xy;
//     end
// end

// reg [3:0] x_pix4, y_pix4;
// always @(posedge clk or negedge rst_n) begin : X_and_Y_stage4
//     if(!rst_n) begin
//         x_pix4 <= 0;
//         y_pix4 <= 0;
//     end
//     else begin
//         x_pix4 <= x_pix3;
//         y_pix4 <= y_pix3;
//     end
// end

// Track valid data down the pipeline
reg [`VALID_TAP_IDX:0] valid_chain;
always @(posedge clk or negedge rst_n) begin : valid_tracking
    if(!rst_n) begin
        valid_chain <= 0;
    end else begin
        valid_chain <= {valid_chain[`VALID_TAP_IDX-1:0], in_valid};
    end
end

// Local coordinate counter for the DPC window
reg [3:0] win_x, win_y;
always @(posedge clk or negedge rst_n) begin : win_coord_counter
    if(!rst_n) begin
        win_x <= 0;
        win_y <= 0;
    end else if(valid_chain[`VALID_TAP_IDX]) begin // Triggered dynamically
        if(win_x == 15) begin
            win_x <= 0;
            win_y <= win_y + 1;
        end else begin
            win_x <= win_x + 1;
        end
    end
end

// =========================================================
// stage 5: DPC
// =========================================================
reg [3:0] x_pix5, y_pix5;
always @(posedge clk or negedge rst_n) begin : X_and_Y_stage5
    if(!rst_n) begin
        x_pix5 <= 0;
        y_pix5 <= 0;
    end
    else begin
        x_pix5 <= win_x;
        y_pix5 <= win_y;
    end
end

// DPC shift regs, act as the 4th pipeline reg layer(s)
reg [11:0] pixel_buf[`DPC_REG_CNT-1:0];
always @(posedge clk or negedge rst_n) begin : DPC_shift_reg
    if(!rst_n) begin
        for(integer i = 0; i< `DPC_REG_CNT;i=i+1) pixel_buf[i] <= 0;
    end
    else begin
        // the first reg takes the pixel output from the prev stage
        pixel_buf[0] <= Pprime_xy;
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
    .coord(win_x), // Changed from x_pix4
    .pix_lb(winx_pix_lb),
    .pix_ub(winx_pix_ub)
);

Coor2WinBounds win_bound_y (
    .coord(win_y), // Changed from y_pix4
    .pix_lb(winy_pix_lb),
    .pix_ub(winy_pix_ub)
);

// DPC window value logic so we can fix the center of the 5x5 window on pixel_buf[WIN_CENTER_IDX]
always @(*) begin : DPC_window_assign_logic
    for (integer i=0;i<5;i=i+1) begin : pixel_valid_assign
        for(integer j=0;j<5;j=j+1) begin
            DPC_WIN5X5[i][j] = 0; // default value, will be overwritten in the padding step
        end
    end

    // assign the pixel values in the valid region
    for (integer i=0;i<5;i=i+1) begin : pixel_valid_assign
        for(integer j=0;j<5;j=j+1) begin
            if(i >= winy_pix_lb && i <= winy_pix_ub && j >= winx_pix_lb && j <= winx_pix_ub) begin
                // Note: DPC_WIN5X5[y][x], i -> y, j -> x
                DPC_WIN5X5[i][j] = pixel_buf[`WIN_CENTER_IDX - (j-2) - (i-2)*16];
            end
        end
    end

    // Step 1: horizontal padding
    // Within the valid y range, clone the vlaues from the valid region to their mirrored counterparts
    // e.g. if winx_pix_lb = 1, winx_pix_ub = 4, then we clone the values in col 2 to col 0
    for (integer i=0;i<5;i=i+1) begin : horizontal_padding
        for(integer j=0;j<5;j=j+1) begin
            if(i >= winy_pix_lb && i <= winy_pix_ub) begin
                if(j < winx_pix_lb) begin
                    DPC_WIN5X5[i][j] = DPC_WIN5X5[i][winx_pix_lb + (winx_pix_lb - j)];
                end
                else if(j > winx_pix_ub) begin
                    DPC_WIN5X5[i][j] = DPC_WIN5X5[i][winx_pix_ub - (j - winx_pix_ub)];
                end
            end
        end
    end

    // Step 2: Vertical padding
    for (integer j=0;j<5;j=j+1) begin : vertical_padding
        for(integer i=0;i<5;i=i+1) begin
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

// =========================================================
// 1. Find the medians on the 4 directions
// =========================================================
wire [11:0] sort_h_0, sort_h_1, sort_h_2, sort_h_3;
Sorter4 sort_h(.in0(DPC_WIN5X5[2][0]), .in1(DPC_WIN5X5[2][1]), .in2(DPC_WIN5X5[2][3]), .in3(DPC_WIN5X5[2][4]),
                .out0(sort_h_0), .out1(sort_h_1), .out2(sort_h_2), .out3(sort_h_3));
wire [11:0] med_h = (sort_h_1 + sort_h_2) >> 1;

wire [11:0] sort_v_0, sort_v_1, sort_v_2, sort_v_3;
Sorter4 sort_v(.in0(DPC_WIN5X5[0][2]), .in1(DPC_WIN5X5[1][2]), .in2(DPC_WIN5X5[3][2]), .in3(DPC_WIN5X5[4][2]),
                .out0(sort_v_0), .out1(sort_v_1), .out2(sort_v_2), .out3(sort_v_3));
wire [11:0] med_v = (sort_v_1 + sort_v_2) >> 1;

wire [11:0] sort_d1_0, sort_d1_1, sort_d1_2, sort_d1_3;
Sorter4 sort_d1(.in0(DPC_WIN5X5[0][0]), .in1(DPC_WIN5X5[1][1]), .in2(DPC_WIN5X5[3][3]), .in3(DPC_WIN5X5[4][4]),
                .out0(sort_d1_0), .out1(sort_d1_1), .out2(sort_d1_2), .out3(sort_d1_3));
wire [11:0] med_d1 = (sort_d1_1 + sort_d1_2) >> 1;

wire [11:0] sort_d2_0, sort_d2_1, sort_d2_2, sort_d2_3;
Sorter4 sort_d2(.in0(DPC_WIN5X5[0][4]), .in1(DPC_WIN5X5[1][3]), .in2(DPC_WIN5X5[3][1]), .in3(DPC_WIN5X5[4][0]),
                .out0(sort_d2_0), .out1(sort_d2_1), .out2(sort_d2_2), .out3(sort_d2_3));
wire [11:0] med_d2 = (sort_d2_1 + sort_d2_2) >> 1;

// =========================================================
// 2. Sum of SAD scores on 4 dirs
// =========================================================
wire [11:0] diff_h0 = (DPC_WIN5X5[2][0] > med_h) ? DPC_WIN5X5[2][0] - med_h : med_h - DPC_WIN5X5[2][0];
wire [11:0] diff_h1 = (DPC_WIN5X5[2][1] > med_h) ? DPC_WIN5X5[2][1] - med_h : med_h - DPC_WIN5X5[2][1];
wire [11:0] diff_h2 = (DPC_WIN5X5[2][3] > med_h) ? DPC_WIN5X5[2][3] - med_h : med_h - DPC_WIN5X5[2][3];
wire [11:0] diff_h3 = (DPC_WIN5X5[2][4] > med_h) ? DPC_WIN5X5[2][4] - med_h : med_h - DPC_WIN5X5[2][4];
wire [13:0] sad_h = diff_h0 + diff_h1 + diff_h2 + diff_h3;

wire [11:0] diff_v0 = (DPC_WIN5X5[0][2] > med_v) ? DPC_WIN5X5[0][2] - med_v : med_v - DPC_WIN5X5[0][2];
wire [11:0] diff_v1 = (DPC_WIN5X5[1][2] > med_v) ? DPC_WIN5X5[1][2] - med_v : med_v - DPC_WIN5X5[1][2];
wire [11:0] diff_v2 = (DPC_WIN5X5[3][2] > med_v) ? DPC_WIN5X5[3][2] - med_v : med_v - DPC_WIN5X5[3][2];
wire [11:0] diff_v3 = (DPC_WIN5X5[4][2] > med_v) ? DPC_WIN5X5[4][2] - med_v : med_v - DPC_WIN5X5[4][2];
wire [13:0] sad_v = diff_v0 + diff_v1 + diff_v2 + diff_v3;

wire [11:0] diff_d10 = (DPC_WIN5X5[0][0] > med_d1) ? DPC_WIN5X5[0][0] - med_d1 : med_d1 - DPC_WIN5X5[0][0];
wire [11:0] diff_d11 = (DPC_WIN5X5[1][1] > med_d1) ? DPC_WIN5X5[1][1] - med_d1 : med_d1 - DPC_WIN5X5[1][1];
wire [11:0] diff_d12 = (DPC_WIN5X5[3][3] > med_d1) ? DPC_WIN5X5[3][3] - med_d1 : med_d1 - DPC_WIN5X5[3][3];
wire [11:0] diff_d13 = (DPC_WIN5X5[4][4] > med_d1) ? DPC_WIN5X5[4][4] - med_d1 : med_d1 - DPC_WIN5X5[4][4];
wire [13:0] sad_d1 = diff_d10 + diff_d11 + diff_d12 + diff_d13;

wire [11:0] diff_d20 = (DPC_WIN5X5[0][4] > med_d2) ? DPC_WIN5X5[0][4] - med_d2 : med_d2 - DPC_WIN5X5[0][4];
wire [11:0] diff_d21 = (DPC_WIN5X5[1][3] > med_d2) ? DPC_WIN5X5[1][3] - med_d2 : med_d2 - DPC_WIN5X5[1][3];
wire [11:0] diff_d22 = (DPC_WIN5X5[3][1] > med_d2) ? DPC_WIN5X5[3][1] - med_d2 : med_d2 - DPC_WIN5X5[3][1];
wire [11:0] diff_d23 = (DPC_WIN5X5[4][0] > med_d2) ? DPC_WIN5X5[4][0] - med_d2 : med_d2 - DPC_WIN5X5[4][0];
wire [13:0] sad_d2 = diff_d20 + diff_d21 + diff_d22 + diff_d23;

// =========================================================
// 3. Select the median of the dir with min SAD as the target
// tie-breaking: H -> V -> D1 -> D2
// =========================================================
wire [13:0] min_sad_hv;
wire [11:0] target_hv;
assign min_sad_hv = (sad_h <= sad_v) ? sad_h : sad_v;
assign target_hv  = (sad_h <= sad_v) ? med_h : med_v;

wire [13:0] min_sad_d1d2;
wire [11:0] target_d1d2;
assign min_sad_d1d2 = (sad_d1 <= sad_d2) ? sad_d1 : sad_d2;
assign target_d1d2  = (sad_d1 <= sad_d2) ? med_d1 : med_d2;

wire [13:0] final_min_sad;
wire [11:0] final_target;
assign final_min_sad = (min_sad_hv <= min_sad_d1d2) ? min_sad_hv : min_sad_d1d2;
assign final_target  = (min_sad_hv <= min_sad_d1d2) ? target_hv  : target_d1d2;

// =========================================================
// 4. Replace the center pixel with the target if |P-target| > 320
// =========================================================
wire [11:0] center_p = DPC_WIN5X5[2][2];
wire [11:0] diff_p_target = (center_p > final_target) ? (center_p - final_target) : (final_target - center_p);

wire [11:0] dpc_corrected_pixel;
assign dpc_corrected_pixel = (diff_p_target > 12'd320) ? final_target : center_p;

// =========================================================
// 5. Reg output sent to the 6th stage, and also save the 3x3 window values for the demosaic stage to synchronize with the DPC output
// =========================================================
reg [11:0] dpc_reg;
reg [11:0] demos_win [0:7]; // NW, N, NE, W, E, SW, S, SE

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dpc_reg <= 0;
        for (integer i = 0; i < 8; i = i + 1) demos_win[i] <= 0;
    end else begin
        dpc_reg <= dpc_corrected_pixel;
        // Save the 3x3 surrounding neighbors to synchronize with the DPC output
        demos_win[0] <= DPC_WIN5X5[1][1]; // NW
        demos_win[1] <= DPC_WIN5X5[1][2]; // N
        demos_win[2] <= DPC_WIN5X5[1][3]; // NE
        demos_win[3] <= DPC_WIN5X5[2][1]; // W
        demos_win[4] <= DPC_WIN5X5[2][3]; // E
        demos_win[5] <= DPC_WIN5X5[3][1]; // SW
        demos_win[6] <= DPC_WIN5X5[3][2]; // S
        demos_win[7] <= DPC_WIN5X5[3][3]; // SE
    end
end

// =========================================================
// stage 6
// =========================================================

// Demos
wire [11:0] Rout5, Gout5, Bout5;
DemosMod demod(
    .NW(demos_win[0]),
    .N(demos_win[1]),
    .NE(demos_win[2]),
    .W(demos_win[3]),
    .E(demos_win[4]),
    .SW(demos_win[5]),
    .S(demos_win[6]),
    .SE(demos_win[7]),
    .C(dpc_reg),
    .x(x_pix5),
    .y(y_pix5),
    .Rout(Rout5),
    .Gout(Gout5),
    .Bout(Bout5)
);

// CCM (Not modularized to foster flexibility in pipelining)

// Extend to 13-bit signed to ensure correct signed multiplication
wire signed [12:0] R_signed = {1'b0, Rout5};
wire signed [12:0] G_signed = {1'b0, Gout5};
wire signed [12:0] B_signed = {1'b0, Bout5};

// ---------------------------------------------------------
// CCM Multiplication Block
// ---------------------------------------------------------
// Calculate the 1100 multiples (Requires 24 bits)
wire signed [23:0] R_mul_1100 = R_signed * 1100;
wire signed [23:0] G_mul_1100 = G_signed * 1100;
wire signed [23:0] B_mul_1100 = B_signed * 1100;

// Calculate the 50 multiples (Requires 24 bits to match the addition tree)
wire signed [23:0] R_mul_50 = R_signed * 50;
wire signed [23:0] G_mul_50 = G_signed * 50;
wire signed [23:0] B_mul_50 = B_signed * 50;

// ---------------------------------------------------------
// CCM Addition Block
// ---------------------------------------------------------
reg signed [23:0] Rmm, Gmm, Bmm;

always @(*) begin
    Rmm =  R_mul_1100 - G_mul_50   - B_mul_50   + 512;
    Gmm = -R_mul_50   + G_mul_1100 - B_mul_50   + 512;
    Bmm = -R_mul_50   - G_mul_50   + B_mul_1100 + 512;
end

// ---------------------------------------------------------
// Shift and Saturation Clip
// ---------------------------------------------------------
// Arithmetic right shift by 10
wire signed [13:0] R_shift = Rmm >>> 10;
wire signed [13:0] G_shift = Gmm >>> 10;
wire signed [13:0] B_shift = Bmm >>> 10;

// Clamp values below 0 to 0, and values above 4095 to 4095
wire [11:0] R_clip = (R_shift < 0) ? 12'd0 : (R_shift > 4095) ? 12'd4095 : R_shift[11:0];
wire [11:0] G_clip = (G_shift < 0) ? 12'd0 : (G_shift > 4095) ? 12'd4095 : G_shift[11:0];
wire [11:0] B_clip = (B_shift < 0) ? 12'd0 : (B_shift > 4095) ? 12'd4095 : B_shift[11:0];

// 255-cycle delay chain for out_valid
reg [`TARGET_LATENCY-1:0] out_valid_chain;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid_chain <= 0;
    end else begin
        out_valid_chain <= {out_valid_chain[`TARGET_LATENCY-2:0], in_valid};
    end
end

// Trigger out_valid exactly when the data arrives
always @(*) begin
    out_valid = out_valid_chain[`TARGET_LATENCY-1]; 
end

always @(posedge clk or negedge rst_n) begin : out_reg
    if(!rst_n) begin
        r_out <= 0;
        g_out <= 0;
        b_out <= 0;
    end
    else if (out_valid_chain[`TARGET_LATENCY-2]) begin // Evaluates 1 cycle before out_valid goes high
        r_out <= R_clip;
        g_out <= G_clip;
        b_out <= B_clip;
    end
    else begin
        // Forces outputs to strictly 0 when out_valid is low
        r_out <= 0;
        g_out <= 0;
        b_out <= 0;
    end
end

endmodule