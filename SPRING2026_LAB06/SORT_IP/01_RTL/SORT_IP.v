//###############################################################################################
//    File Name   : SORT_IP.v
//    Module Name : SORT_IP
//    Description : Odd-Even Merge Sort Network (Stable Sort, MSB Priority)
//###############################################################################################

module SORT_IP #(parameter IP_WIDTH = 8)(
    input  [IP_WIDTH*4-1:0] IN_character, 
    input  [IP_WIDTH*5-1:0] IN_weight,
    output [IP_WIDTH*4-1:0] OUT_character
);

// ======================================================
// 1. Pack Stage: (Weight 5-bit) + (Priority 3-bit) + (Char 4-bit) = 12-bit
// ======================================================
wire [11:0] w[0:7];

assign w[0] = {IN_weight[39:35], 3'd7, IN_character[31:28]};
assign w[1] = {IN_weight[34:30], 3'd6, IN_character[27:24]};
assign w[2] = {IN_weight[29:25], 3'd5, IN_character[23:20]};
assign w[3] = {IN_weight[24:20], 3'd4, IN_character[19:16]};
assign w[4] = {IN_weight[19:15], 3'd3, IN_character[15:12]};
assign w[5] = {IN_weight[14:10], 3'd2, IN_character[11:8]};
assign w[6] = {IN_weight[9:5],   3'd1, IN_character[7:4]};
assign w[7] = {IN_weight[4:0],   3'd0, IN_character[3:0]};

// ======================================================
// 2. Sorting Network Stage (Total 19 CAS units for N=8)
// ======================================================

// Stage 1 (Sort pairs: 0-1, 2-3, 4-5, 6-7)
wire [11:0] st1_0, st1_1, st1_2, st1_3, st1_4, st1_5, st1_6, st1_7;
CAS c1_0(.in_a(w[0]), .in_b(w[1]), .out_high(st1_0), .out_low(st1_1));
CAS c1_1(.in_a(w[2]), .in_b(w[3]), .out_high(st1_2), .out_low(st1_3));
CAS c1_2(.in_a(w[4]), .in_b(w[5]), .out_high(st1_4), .out_low(st1_5));
CAS c1_3(.in_a(w[6]), .in_b(w[7]), .out_high(st1_6), .out_low(st1_7));

// Stage 2 (Sort 4-blocks, step 1: 0-2, 1-3, 4-6, 5-7)
wire [11:0] st2_0, st2_1, st2_2, st2_3, st2_4, st2_5, st2_6, st2_7;
CAS c2_0(.in_a(st1_0), .in_b(st1_2), .out_high(st2_0), .out_low(st2_2));
CAS c2_1(.in_a(st1_1), .in_b(st1_3), .out_high(st2_1), .out_low(st2_3));
CAS c2_2(.in_a(st1_4), .in_b(st1_6), .out_high(st2_4), .out_low(st2_6));
CAS c2_3(.in_a(st1_5), .in_b(st1_7), .out_high(st2_5), .out_low(st2_7));

// Stage 3 (Sort 4-blocks, step 2: 1-2, 5-6)
wire [11:0] st3_0, st3_1, st3_2, st3_3, st3_4, st3_5, st3_6, st3_7;
assign st3_0 = st2_0;
assign st3_3 = st2_3;
assign st3_4 = st2_4;
assign st3_7 = st2_7;
CAS c3_0(.in_a(st2_1), .in_b(st2_2), .out_high(st3_1), .out_low(st3_2));
CAS c3_1(.in_a(st2_5), .in_b(st2_6), .out_high(st3_5), .out_low(st3_6));

// Stage 4 (Merge two 4-blocks: 0-4, 1-5, 2-6, 3-7)
wire [11:0] st4_0, st4_1, st4_2, st4_3, st4_4, st4_5, st4_6, st4_7;
CAS c4_0(.in_a(st3_0), .in_b(st3_4), .out_high(st4_0), .out_low(st4_4));
CAS c4_1(.in_a(st3_1), .in_b(st3_5), .out_high(st4_1), .out_low(st4_5));
CAS c4_2(.in_a(st3_2), .in_b(st3_6), .out_high(st4_2), .out_low(st4_6));
CAS c4_3(.in_a(st3_3), .in_b(st3_7), .out_high(st4_3), .out_low(st4_7));

// Stage 5 (Merge step 2: 2-4, 3-5)
wire [11:0] st5_0, st5_1, st5_2, st5_3, st5_4, st5_5, st5_6, st5_7;
assign st5_0 = st4_0;
assign st5_1 = st4_1;
assign st5_6 = st4_6;
assign st5_7 = st4_7;
CAS c5_0(.in_a(st4_2), .in_b(st4_4), .out_high(st5_2), .out_low(st5_4));
CAS c5_1(.in_a(st4_3), .in_b(st4_5), .out_high(st5_3), .out_low(st5_5));

// Stage 6 (Final Merge step: 1-2, 3-4, 5-6)
wire [11:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7;
assign out_0 = st5_0;
assign out_7 = st5_7;
CAS c6_0(.in_a(st5_1), .in_b(st5_2), .out_high(out_1), .out_low(out_2));
CAS c6_1(.in_a(st5_3), .in_b(st5_4), .out_high(out_3), .out_low(out_4));
CAS c6_2(.in_a(st5_5), .in_b(st5_6), .out_high(out_5), .out_low(out_6));

// ======================================================
// 3. Unpack Stage: Extract Char (Lowest 4-bit)
// ======================================================
assign OUT_character = {
    out_0[3:0], out_1[3:0], out_2[3:0], out_3[3:0], 
    out_4[3:0], out_5[3:0], out_6[3:0], out_7[3:0]
};

endmodule

// ======================================================
// Sub-module: Compare-And-Swap (CAS)
// ======================================================
module CAS(
    input  [11:0] in_a,
    input  [11:0] in_b,
    output [11:0] out_high, 
    output [11:0] out_low   
);
    //  Weight (5-bit) + Priority (3-bit)
    wire cmp = (in_a[11:4] > in_b[11:4]); 
    
    assign out_high = cmp ? in_a : in_b;
    assign out_low  = cmp ? in_b : in_a;
endmodule