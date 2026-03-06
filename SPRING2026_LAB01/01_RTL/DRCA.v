module CheckMask(
    input  wire [17:0] data_in,
    input  wire        rule_type,
    // the occurence is reported on the left most 1/0, left meaning towards the MSB
    output wire [17:0] match_010_or_101,
    output wire [17:0] match_0110_or_1001,
    output wire [17:0] match_01110_or_10001,
    output wire [17:0] match_011110
);
    // MSB-left bit ordering: bit[15] is leftmost, bit[0] is rightmost.
    // At position k, its left  neighbor is bit[k+1] (higher index, toward MSB).
    //                its right neighbor is bit[k-1] (lower  index, toward LSB).
    // To read the left  neighbor at every k simultaneously: shift data RIGHT (>>) by 1
    //   → shr1[k] = data[k+1]
    // To read the right neighbor at every k simultaneously: shift data LEFT  (<<) by 1
    //   → shl1[k] = data[k-1]
    // Example: data_in >> 1: 0 D[15] D[14] ... D[2] D[1]  (shr1[k] = D[k+1])

    // Modified data and shifts for the first three patterns (supports inversion via rule_type)
    wire [17:0] data_mod = data_in ^ {18{rule_type}};
    wire [17:0] shr1 = {rule_type, data_mod[17:1]}; // shr1[k] = data_mod[k+1]: left  neighbor of k; MSB padded with rule_type
    wire [17:0] shl1 = {data_mod[16:0], rule_type};  // shl1[k] = data_mod[k-1]: right neighbor of k, 1 away; LSB padded with rule_type
    wire [17:0] shl2 = {data_mod[15:0], {2{rule_type}}}; // shl2[k] = data_mod[k-2]: right neighbor of k, 2 away
    wire [17:0] shl3 = {data_mod[14:0], {3{rule_type}}}; // shl3[k] = data_mod[k-3]: right neighbor of k, 3 away

    // Raw data and shifts for the 011110 pattern (fixed 0 padding, no inversion)
    wire [17:0] raw_shr1 = {1'b0, data_in[17:1]};         // raw_shr1[k] = data_in[k+1]
    wire [17:0] raw_shl1 = {data_in[16:0], 1'b0};          // raw_shl1[k] = data_in[k-1]
    wire [17:0] raw_shl2 = {data_in[15:0], 2'b00};          // raw_shl2[k] = data_in[k-2]
    wire [17:0] raw_shl3 = {data_in[14:0], 3'b000};         // raw_shl3[k] = data_in[k-3]
    wire [17:0] raw_shl4 = {data_in[13:0], 4'b0000};        // raw_shl4[k] = data_in[k-4]

    // 1. 010 / 101: isolated 1/0. At match bit k: data_mod[k+1..k-1] = 0,1,0.
    //    Reported at bit k (the sole 1/0 of the run).
    assign match_010_or_101 = ~shr1 & data_mod & ~shl1;

    // 2. 0110 / 1001: run of two 1/0s. At match bit k: data_mod[k+1..k-2] = 0,1,1,0.
    //    Reported at bit k (leftmost 1/0 of the pair).
    assign match_0110_or_1001 = ~shr1 & data_mod & shl1 & ~shl2;

    // 3. 01110 / 10001: run of three 1/0s. At match bit k: data_mod[k+1..k-3] = 0,1,1,1,0.
    //    Reported at bit k (leftmost 1/0 of the triple).
    assign match_01110_or_10001 = ~shr1 & data_mod & shl1 & shl2 & ~shl3;

    // 4. 011110 only: run of four 1s. At match bit k: data_in[k+1..k-4] = 0,1,1,1,1,0.
    //    Reported at bit k (leftmost 1 of the quad).
    assign match_011110 = ~raw_shr1 & data_in & raw_shl1 & raw_shl2 & raw_shl3 & ~raw_shl4;

endmodule

module RuleValMode_Decoder (
    input rule_type,
    input [2:0] rule_layer,
    output [1:0] rule_val_mode
);
reg [1:0] s_rvm;
reg [1:0] w_rvm;

always@(*) begin  : rvm_decoding_logic
    casez(rule_layer) 
        3'd0, 3'd2: s_rvm = 0;
        3'd1, 3'd3: s_rvm = 1;
        3'd4, 3'd5: s_rvm = 2;
        3'd6: s_rvm = 3;
        default: s_rvm = 3'bx;
    endcase

    casez(rule_layer)
        3'd0, 3'd1, 3'd2, 3'd3: w_rvm = 0;
        3'd4, 3'd5: w_rvm = 1;
        3'd6: w_rvm = 2;
        default: w_rvm = 3'bx;
    endcase
end

assign rule_val_mode = rule_type ? w_rvm : s_rvm;

endmodule

// add 1 violation if row1 has a certain type of violation but row2 doesn't, 
// or vice versa
module RowMod (
    input [17:0] row1,
    input [17:0] row2,
    input rule_type,
    input [2:0] rule_layer,
    input [1:0] rvm,
    output reg [3:0] total_nv
);
    // apply CheckMask to each row
    wire [17:0] match_010_or_101_row1, match_0110_or_1001_row1, match_01110_or_10001_row1, match_011110_row1;
    wire [17:0] match_010_or_101_row2, match_0110_or_1001_row2, match_01110_or_10001_row2, match_011110_row2;
    CheckMask check_row1 (
        .data_in(row1),
        .rule_type(rule_type),
        .match_010_or_101(match_010_or_101_row1),
        .match_0110_or_1001(match_0110_or_1001_row1),
        .match_01110_or_10001(match_01110_or_10001_row1),
        .match_011110(match_011110_row1)
    );
    CheckMask check_row2 (
        .data_in(row2),
        .rule_type(rule_type),
        .match_010_or_101(match_010_or_101_row2),
        .match_0110_or_1001(match_0110_or_1001_row2),
        .match_01110_or_10001(match_01110_or_10001_row2),
        .match_011110(match_011110_row2)
    );

    // check for occurence of the same type of match on the exact same loc on the 2 rows
    wire [17:0] v1_overlap;
    assign v1_overlap = match_010_or_101_row1 & ~match_010_or_101_row2;
    // max num of v2(0110/1001): 17
    //idx| 17 16 15        2  1  0 |
    // 0 | 1  1   0... ==> 0  1  1 | 0
    // check output (match_0110_or_1001_row1 & match_0110_or_1001_row2)
    //   | 1 0 0...    ==> 0  1  0 |  so there are 17 possible locations for v2 cuz the pattern is reported at the left most 1, 
    wire [17:0] v2_xor;
    assign v2_xor = match_0110_or_1001_row1 & ~match_0110_or_1001_row2;
    wire [16:0] v2_overlap;
    assign v2_overlap = v2_xor[17:1];

    wire [17:0] v3_xor;
    assign v3_xor = match_01110_or_10001_row1 & ~match_01110_or_10001_row2;
    wire [15:0] v3_overlap;
    // assign v3_overlap = v3_xor[16:1];
    assign v3_overlap = v3_xor[17:2];

    wire [17:0] v4_xor;
    assign v4_xor = match_011110_row1 & ~match_011110_row2;
    wire [14:0] v4_overlap;
    // assign v4_overlap = v4_xor[15:1];
    assign v4_overlap = v4_xor[17:3];

    // sum up the total num of violations for this row pair
    // note that in the real case, at most 8 violations can occur on one row
    // so we can use 4 bits to count each type of violation, and 4 bits to sum up the total (max 15)
    reg [3:0] v1_count, v2_count, v3_count, v4_count;

    // count the number of 1s in v1_overlap, v2_overlap, v3_overlap, v4_overlap
    always @(*) begin
        v1_count = 0;
        v2_count = 0;
        v3_count = 0;
        v4_count = 0;
        for (integer k = 0; k < 18; k = k + 1)
            v1_count = v1_count + v1_overlap[k];
        for (integer k = 0; k < 17; k = k + 1)
            v2_count = v2_count + v2_overlap[k];
        for (integer k = 0; k < 16; k = k + 1)
            v3_count = v3_count + v3_overlap[k];
        for (integer k = 0; k < 15; k = k + 1)
            v4_count = v4_count + v4_overlap[k];
    end
    reg [3:0] w1_nv, w2_nv, w3_nv, w4_nv;
    // total violations for this row pair = v1_count + v2_count + v3_count + v4_count
    always @(*) begin : RowMod_mode_selection_logic
        w1_nv = v1_count;
        w2_nv = w1_nv + v2_count;
        w3_nv = w2_nv + v3_count;
        w4_nv = w3_nv + v4_count;

        casez(rvm)
        2'd0: total_nv = w1_nv; // only count v1
        2'd1: total_nv = w2_nv; // count v1 and v2
        2'd2: total_nv = w3_nv; // count v1, v2 and v3
        2'd3: total_nv = w4_nv; // count all v1, v2, v3 and v4
        default: total_nv = 4'bx; // invalid rvm
        endcase
    end
endmodule

module DRCA (
    input [3:0]  drc_sel,
    input [18:0] shape0 ,
    input [18:0] shape1 ,
    input [18:0] shape2 ,
    input [18:0] shape3 ,
    input [18:0] shape4 ,
    input [18:0] shape5 ,
    input [18:0] shape6 ,
    input [18:0] shape7 ,
    input [18:0] shape8 ,
    input [18:0] shape9 ,
    input [18:0] shape10 ,
    input [18:0] shape11 ,
    input [18:0] shape12 ,
    input [18:0] shape13 ,
    input [18:0] shape14 ,
    input [18:0] shape15 ,
    output [4:0] drc_out
);


//**************************************************
// Parameter 
//**************************************************
// Rule type for rule_layer
`define CONTACT 3'd0
`define DIFF 3'd1
`define POLY 3'd2
`define M1 3'd3
`define NP 3'd4
`define PP 3'd5
`define NW 3'd6

//**************************************************
// Reg & Wire 
//**************************************************
wire [2:0] shape_layer [0:15];
wire [3:0] llx [0:15];
wire [3:0] lly [0:15];
wire [3:0] urx [0:15];
wire [3:0] ury [0:15];
wire rule_type; // 0: width, 1: spacing
wire [2:0] rule_layer; // 3'd0: contact, 3'd1: diff, 3'd2: poly, 3'd3: m1, 3'd4: np, 3'd5: pp, 3'd6: nw

// grid for the selected layer (18x18 with zero-padded borders)
wire [17:0] grid[0:17];
// indicate if the shape_layer[i] == rule_layer for each shape 
wire is_layer_2_Check[0:15];

// the total num of violations caused by width and spacing 
wire [4:0] width_nv;
wire [4:0] spacing_nv;

// get rule value mode
wire [1:0] rvm;

//**************************************************
// Design 
//**************************************************
// unpack input shapes, assigned wires: shape_layer, llx, lly, urx, ury
genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : unpack_shapes
        assign shape_layer[i] = (i == 0) ? shape0[18:16] :
                               (i == 1) ? shape1[18:16] :
                               (i == 2) ? shape2[18:16] :
                               (i == 3) ? shape3[18:16] :
                               (i == 4) ? shape4[18:16] :
                               (i == 5) ? shape5[18:16] :
                               (i == 6) ? shape6[18:16] :
                               (i == 7) ? shape7[18:16] :
                               (i == 8) ? shape8[18:16] :
                               (i == 9) ? shape9[18:16] :
                               (i == 10) ? shape10[18:16] :
                               (i == 11) ? shape11[18:16] :
                               (i == 12) ? shape12[18:16] :
                               (i == 13) ? shape13[18:16] :
                               (i == 14) ? shape14[18:16] :
                                            shape15[18:16];
        assign llx[i] = (i == 0) ? shape0[15:12] :
                        (i == 1) ? shape1[15:12] :
                        (i == 2) ? shape2[15:12] :
                        (i == 3) ? shape3[15:12] :
                        (i == 4) ? shape4[15:12] :
                        (i == 5) ? shape5[15:12] :
                        (i == 6) ? shape6[15:12] :
                        (i == 7) ? shape7[15:12] :
                        (i == 8) ? shape8[15:12] :
                        (i == 9) ? shape9[15:12] :
                        (i == 10) ? shape10[15:12] :
                        (i == 11) ? shape11[15:12] :
                        (i == 12) ? shape12[15:12] :
                        (i == 13) ? shape13[15:12] :
                        (i == 14) ? shape14[15:12] :
                                     shape15[15:12];
        assign lly[i] = (i == 0) ? shape0[11:8] :
                        (i == 1) ? shape1[11:8] :
                        (i == 2) ? shape2[11:8] :
                        (i == 3) ? shape3[11:8] :       
                        (i == 4) ? shape4[11:8] :
                        (i == 5) ? shape5[11:8] :
                        (i == 6) ? shape6[11:8] :
                        (i == 7) ? shape7[11:8] :
                        (i == 8) ? shape8[11:8] :
                        (i == 9) ? shape9[11:8] :
                        (i == 10) ? shape10[11:8] :
                        (i == 11) ? shape11[11:8] :
                        (i == 12) ? shape12[11:8] :
                        (i == 13) ? shape13[11:8] :
                        (i == 14) ? shape14[11:8] :
                                     shape15[11:8];
        assign urx[i] = (i == 0) ? shape0[7:4] :
                        (i == 1) ? shape1[7:4] :
                        (i == 2) ? shape2[7:4] :
                        (i == 3) ? shape3[7:4] :
                        (i == 4) ? shape4[7:4] :
                        (i == 5) ? shape5[7:4] :
                        (i == 6) ? shape6[7:4] :
                        (i == 7) ? shape7[7:4] :
                        (i == 8) ? shape8[7:4] :
                        (i == 9) ? shape9[7:4] :
                        (i == 10) ? shape10[7:4] :
                        (i == 11) ? shape11[7:4] :
                        (i == 12) ? shape12[7:4] :
                        (i == 13) ? shape13[7:4] :
                        (i == 14) ? shape14[7:4] :
                                     shape15[7:4];
        assign ury[i] = (i == 0) ? shape0[3:0] :
                        (i == 1) ? shape1[3:0] :
                        (i == 2) ? shape2[3:0] :
                        (i == 3) ? shape3[3:0] :
                        (i == 4) ? shape4[3:0] :
                        (i == 5) ? shape5[3:0] :
                        (i == 6) ? shape6[3:0] :    
                        (i == 7) ? shape7[3:0] :
                        (i == 8) ? shape8[3:0] :
                        (i == 9) ? shape9[3:0] :
                        (i == 10) ? shape10[3:0] :
                        (i == 11) ? shape11[3:0] :
                        (i == 12) ? shape12[3:0] :
                        (i == 13) ? shape13[3:0] :
                        (i == 14) ? shape14[3:0] :
                                     shape15[3:0];
    end
endgenerate
// unpack DRC rule
assign rule_type = drc_sel[0]; // LSB indicates rule type
assign rule_layer = drc_sel[3:1]; // MSBs indicate layer for width/spacing rules

// get rule value mode (depends on rule type and rule layer)
RuleValMode_Decoder rvm_decoder (
    .rule_type(rule_type),
    .rule_layer(rule_layer),
    .rule_val_mode(rvm)
);

// translate shape_layer to rule_layer 
reg [2:0] trans_rule_layer;
always @(*) begin
    // for (integer idx = 0; idx < 16; idx = idx + 1) begin
    //     casez(shape_layer[idx])
    //     3'd1: trans_shape_layer[idx] = 3'd0; // CO
    //     3'd2: trans_shape_layer[idx] = 3'd1; // OD
    //     3'd3: trans_shape_layer[idx] = 3'd2; // PO
    //     3'd4: trans_shape_layer[idx] = 3'd3; // M1
    //     3'd5: trans_shape_layer[idx] = 3'd4; // NP
    //     3'd6: trans_shape_layer[idx] = 3'd5; // PP
    //     3'd7: trans_shape_layer[idx] = 3'd6; // NW
    //     default: trans_shape_layer[idx] = 3'bx;
    //     endcase
    // end

    // translate rule layer to shape layer
    casez(rule_layer)
        3'd0: trans_rule_layer = 3'd1; // CO
        3'd1: trans_rule_layer = 3'd2; // OD
        3'd2: trans_rule_layer = 3'd3; // PO
        3'd3: trans_rule_layer = 3'd4; // M1
        3'd4: trans_rule_layer = 3'd5; // NP
        3'd5: trans_rule_layer = 3'd6; // PP
        3'd6: trans_rule_layer = 3'd7; // NW
        default: trans_rule_layer = 3'bx;
    endcase
end

// check which shapes are on the same layer as the rule_layer, store in is_layer_2_Check
generate
    for (i = 0; i < 16; i = i + 1) begin : check_layer
        assign is_layer_2_Check[i] = (shape_layer[i] == trans_rule_layer) ? 1 : 0;
    end
endgenerate

// construct the grid (18x18 with zero-padded borders, original 16x16 content in [1:16][1:16])
genvar j;
generate
    // The outer border rows (0, 17) and columns (bit 0, bit 17) are zero-padded.
    // The original 16x16 content is placed in grid[1..16][1..16].
    // For a shape with llx=0, lly=4, urx=3, ury=10: grid[1..3][5..10] = 1 (shifted by +1).
    for (i = 0; i < 18; i = i + 1) begin : construct_grids
        for (j = 0; j < 18; j = j + 1) begin : construct_grid_bits
            if (i == 0 || i == 17 || j == 0 || j == 17) begin : zero_pad
                assign grid[i][j] = 1'b0;
            end else begin : interior
                assign grid[i][j] = 
                ((is_layer_2_Check[0]) && (llx[0] <= (i-1)) && (urx[0] > (i-1)) && (lly[0] <= (j-1)) && (ury[0] > (j-1))) ||
                ((is_layer_2_Check[1]) && (llx[1] <= (i-1)) && (urx[1] > (i-1)) && (lly[1] <= (j-1)) && (ury[1] > (j-1))) ||
                ((is_layer_2_Check[2]) && (llx[2] <= (i-1)) && (urx[2] > (i-1)) && (lly[2] <= (j-1)) && (ury[2] > (j-1))) ||
                ((is_layer_2_Check[3]) && (llx[3] <= (i-1)) && (urx[3] > (i-1)) && (lly[3] <= (j-1)) && (ury[3] > (j-1))) ||
                ((is_layer_2_Check[4]) && (llx[4] <= (i-1)) && (urx[4] > (i-1)) && (lly[4] <= (j-1)) && (ury[4] > (j-1))) ||
                ((is_layer_2_Check[5]) && (llx[5] <= (i-1)) && (urx[5] > (i-1)) && (lly[5] <= (j-1)) && (ury[5] > (j-1))) ||
                ((is_layer_2_Check[6]) && (llx[6] <= (i-1)) && (urx[6] > (i-1)) && (lly[6] <= (j-1)) && (ury[6] > (j-1))) ||
                ((is_layer_2_Check[7]) && (llx[7] <= (i-1)) && (urx[7] > (i-1)) && (lly[7] <= (j-1)) && (ury[7] > (j-1))) ||
                ((is_layer_2_Check[8]) && (llx[8] <= (i-1)) && (urx[8] > (i-1)) && (lly[8] <= (j-1)) && (ury[8] > (j-1))) ||
                ((is_layer_2_Check[9]) && (llx[9] <= (i-1)) && (urx[9] > (i-1)) && (lly[9] <= (j-1)) && (ury[9] > (j-1))) ||
                ((is_layer_2_Check[10]) && (llx[10] <= (i-1)) && (urx[10] > (i-1)) && (lly[10] <= (j-1)) && (ury[10] > (j-1))) ||
                ((is_layer_2_Check[11]) && (llx[11] <= (i-1)) && (urx[11] > (i-1)) && (lly[11] <= (j-1)) && (ury[11] > (j-1))) ||
                ((is_layer_2_Check[12]) && (llx[12] <= (i-1)) && (urx[12] > (i-1)) && (lly[12] <= (j-1)) && (ury[12] > (j-1))) ||
                ((is_layer_2_Check[13]) && (llx[13] <= (i-1)) && (urx[13] > (i-1)) && (lly[13] <= (j-1)) && (ury[13] > (j-1))) ||
                ((is_layer_2_Check[14]) && (llx[14] <= (i-1)) && (urx[14] > (i-1)) && (lly[14] <= (j-1)) && (ury[14] > (j-1))) ||
                ((is_layer_2_Check[15]) && (llx[15] <= (i-1)) && (urx[15] > (i-1)) && (lly[15] <= (j-1)) && (ury[15] > (j-1)));
            end
        end
    end
endgenerate

wire [17:0] grid_tr[0:17]; // a transposed version of grid to facilitate counting vertical violations column by column
// transpose the grid to get grid_tr, so that we can reuse RowMod to count vertical violations by treating each column as a row
// genvar i, j;
generate
    for (i = 0; i < 18; i = i + 1) begin : transpose_grid
        for (j = 0; j < 18; j = j + 1) begin
            assign grid_tr[i][j] = grid[j][i];
        end
    end
endgenerate

// Connect the rows of grid to 17 RowMod to count the horizontal violations
// expected inputs dim of RowMod: row1[17:0], row2[17:0], rule_type; output dim: total_nv[4:0]
wire [3:0] h_nv_per_row [0:16];   // one count per adjacent row pair
reg [4:0] h_nv; // total horizontal violations, assigned to h_nv_temp after accumulation
// connecting pair: (0,1), (1,2), ... , (16, 17)
// a total of 17 row pairs, so we need 17 RowMod instances to cover all the horizontal violations between adjacent rows.

generate
    for (i = 0; i < 17; i = i + 1) begin : h_row_mods
    // DRCA.h_row_mods[0].row_mod_h
    // ...
    // DRCA.h_row_mods[16].row_mod_h
        RowMod row_mod_h (
            .row1(grid_tr[i]),
            .row2(grid_tr[i+1]),
            .rule_type(rule_type),
            .rule_layer(rule_layer),
            .rvm(rvm),
            .total_nv(h_nv_per_row[i])
        );
    end
endgenerate

// accumulate the total horizontal violations from each row pair
always @(*) begin
    h_nv = 0;
    for (integer k = 0; k < 17; k = k + 1) begin
        h_nv = h_nv + h_nv_per_row[k];
    end
end

// group the vertical violations by column and count the total num of vertical violations, store in v_nv
reg [4:0] v_nv; // total vertical violations, assigned to v_nv_temp after accumulation
wire [3:0] v_nv_per_col [0:16]; // vertical violations per column

// connecting pair: (0,1), (1,2), ... , (16, 17) of grid to count vertical violations column by column


generate
    for (i = 0; i < 17; i = i + 1) begin : v_row_mods
        RowMod row_mod_v (
            .row1(grid[i]),
            .row2(grid[i+1]),
            .rule_type(rule_type),
            .rule_layer(rule_layer),
            .rvm(rvm),
            .total_nv(v_nv_per_col[i])
        );
    end
endgenerate

// accumulate the total vertical violations from each column pair
always @(*) begin
    v_nv = 0;
    for (integer k = 0; k < 17; k = k + 1) begin
        v_nv = v_nv + v_nv_per_col[k];
    end
end

assign drc_out = h_nv + v_nv; // total violations = horizontal violations + vertical violations

endmodule
