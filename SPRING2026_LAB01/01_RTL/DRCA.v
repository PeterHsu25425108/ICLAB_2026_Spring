module CheckMask(
    input  wire [16:0] data_in,
    output wire [14:0] match_010,       // Bits [15:1]
    output wire [13:0] match_0110,      // Bits [15:2]
    output wire [12:0] match_01110,     // Bits [15:3]
    output wire [11:0] match_011110     // Bits [15:4]   
);
    wire [16:0] shr1 = {data_in[16], data_in[16:1]}; 
    wire [16:0] shl1 = {data_in[15:0], data_in[0]};  
    wire [16:0] shl2 = {data_in[14:0], {2{data_in[0]}}}; 
    wire [16:0] shl3 = {data_in[13:0], {3{data_in[0]}}}; 

    wire [16:0] raw_shr1 = data_in >> 1; 
    wire [16:0] raw_shl1 = data_in << 1; 
    wire [16:0] raw_shl2 = data_in << 2; 
    wire [16:0] raw_shl3 = data_in << 3; 
    wire [16:0] raw_shl4 = data_in << 4; 

    // Intermediate full-width wires
    wire [16:0] m1_full = ~shr1 & data_in & ~shl1;
    wire [16:0] m2_full = ~shr1 & data_in & shl1 & ~shl2;
    wire [16:0] m3_full = ~shr1 & data_in & shl1 & shl2 & ~shl3;
    wire [16:0] m4_full = ~raw_shr1 & data_in & raw_shl1 & raw_shl2 & raw_shl3 & ~raw_shl4;

    // Slice the exact valid bounds
    assign match_010    = m1_full[15:1];
    assign match_0110   = m2_full[15:2];
    assign match_01110  = m3_full[15:3];
    assign match_011110 = m4_full[15:4];
endmodule

module RuleValMode_Decoder (
    // input rule_type,
    // input [2:0] rule_layer,
    // output [1:0] rule_val_mode
    input [3:0] drc_sel,
    output reg[2:0] en_violate
);

always@(*) begin  : rvm_decoding_logic
    case (drc_sel) 
        4'd0, 4'd1, 4'd3, 4'd4, 4'd5, 4'd7: en_violate = 3'b000;
        4'd2, 4'd6, 4'd9, 4'd11: en_violate = 3'b001;
        4'd8, 4'd10, 4'd13: en_violate = 3'b011;
        4'd12: en_violate = 3'b111;
        default: en_violate = 3'bx;
    endcase
end

endmodule

// RowModLite: takes pre-computed CheckMask match vectors for two adjacent rows,
// computes overlap-based violation counts, and selects based on rvm.
// This avoids duplicating CheckMask instances for shared rows between adjacent pairs.
module RowModLite (
    input [14:0] match_v1_row1, match_v1_row2, // 15 bits
    input [13:0] match_v2_row1, match_v2_row2, // 14 bits
    input [12:0] match_v3_row1, match_v3_row2, // 13 bits
    input [11:0] match_v4_row1, match_v4_row2, // 12 bits
    input [2:0] en_violate,
    output wire [3:0] total_nv 
);
    // Early Masking applied directly to the incoming staggered widths
    wire [14:0] v1_overlap_raw = (match_v1_row1 & ~match_v1_row2); 
    wire [13:0] v2_overlap_raw = (match_v2_row1 & ~match_v2_row2) & {14{en_violate[0]}};
    wire [12:0] v3_overlap_raw = (match_v3_row1 & ~match_v3_row2) & {13{en_violate[1]}};
    wire [11:0] v4_overlap_raw = (match_v4_row1 & ~match_v4_row2) & {12{en_violate[2]}};

    // Compression Bounds: Ceil(Length / Dist)
    wire [7:0] v1_overlap; // Ceil(15/2) = 8
    wire [4:0] v2_overlap; // Ceil(14/3) = 5
    wire [3:0] v3_overlap; // Ceil(13/4) = 4 
    wire [2:0] v4_overlap; // Ceil(12/5) = 3 

    reg [3:0] v1_count, v2_count;
    reg [2:0] v3_count;
    reg [1:0] v4_count;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_v1
            if ((i + 1) * 2 > 15) assign v1_overlap[i] = |v1_overlap_raw[14 : i*2];
            else                  assign v1_overlap[i] = |v1_overlap_raw[(i+1)*2-1 : i*2];
        end
        for (i = 0; i < 5; i = i + 1) begin : gen_v2
            if ((i + 1) * 3 > 14) assign v2_overlap[i] = |v2_overlap_raw[13 : i*3];
            else                  assign v2_overlap[i] = |v2_overlap_raw[(i+1)*3-1 : i*3];
        end
        for (i = 0; i < 4; i = i + 1) begin : gen_v3
            if ((i + 1) * 4 > 13) assign v3_overlap[i] = |v3_overlap_raw[12 : i*4];
            else                  assign v3_overlap[i] = |v3_overlap_raw[(i+1)*4-1 : i*4];
        end
        for (i = 0; i < 3; i = i + 1) begin : gen_v4
            if ((i + 1) * 5 > 12) assign v4_overlap[i] = |v4_overlap_raw[11 : i*5];
            else                  assign v4_overlap[i] = |v4_overlap_raw[(i+1)*5-1 : i*5];
        end
    endgenerate

    always @(*) begin
        v1_count = 0; v2_count = 0; v3_count = 0; v4_count = 0;
        for (integer k = 0; k < 8; k = k + 1) v1_count = v1_count + v1_overlap[k];
        for (integer k = 0; k < 5; k = k + 1) v2_count = v2_count + v2_overlap[k];
        for (integer k = 0; k < 4; k = k + 1) v3_count = v3_count + v3_overlap[k];
        for (integer k = 0; k < 3; k = k + 1) v4_count = v4_count + v4_overlap[k];
    end

    assign total_nv = v1_count + v2_count + v3_count + v4_count;
endmodule

module AdderTree16 (
    input  wire [63:0] in_flat, // 16 separate 4-bit values packed into one bus
    output wire [4:0]  out_sum
);
    // ---------------------------------------------------------
    // Layer 1: 8 adders (Summing 4-bit slices)
    // ---------------------------------------------------------
    wire [4:0] l1 [0:7];
    assign l1[0] = in_flat[3:0]   + in_flat[7:4];
    assign l1[1] = in_flat[11:8]  + in_flat[15:12];
    assign l1[2] = in_flat[19:16] + in_flat[23:20];
    assign l1[3] = in_flat[27:24] + in_flat[31:28];
    assign l1[4] = in_flat[35:32] + in_flat[39:36];
    assign l1[5] = in_flat[43:40] + in_flat[47:44];
    assign l1[6] = in_flat[51:48] + in_flat[55:52];
    assign l1[7] = in_flat[59:56] + in_flat[63:60];

    // ---------------------------------------------------------
    // Layer 2: 4 adders
    // ---------------------------------------------------------
    wire [4:0] l2 [0:3];
    assign l2[0] = l1[0] + l1[1];
    assign l2[1] = l1[2] + l1[3];
    assign l2[2] = l1[4] + l1[5];
    assign l2[3] = l1[6] + l1[7];

    // ---------------------------------------------------------
    // Layer 3: 2 adders
    // ---------------------------------------------------------
    wire [4:0] l3 [0:1];
    assign l3[0] = l2[0] + l2[1];
    assign l3[1] = l2[2] + l2[3];

    // ---------------------------------------------------------
    // Layer 4 (Final output): 1 adder
    // ---------------------------------------------------------
    assign out_sum = l3[0] + l3[1];

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

// grid for the selected layer (17x17 with zero-padded borders)
wire [16:0] grid[0:16];
// indicate if the shape_layer[i] == rule_layer for each shape 
wire is_layer_2_Check[0:15];

// get rule value mode
wire [2:0] en_violate;
// wire [1:0] rvm;

//**************************************************
// Design 
//**************************************************
// unpack input shapes, assigned wires: shape_layer, llx, lly, urx, ury
assign shape_layer[0]  = shape0[18:16];   assign llx[0]  = shape0[15:12];   assign lly[0]  = shape0[11:8];   assign urx[0]  = shape0[7:4];   assign ury[0]  = shape0[3:0];
assign shape_layer[1]  = shape1[18:16];   assign llx[1]  = shape1[15:12];   assign lly[1]  = shape1[11:8];   assign urx[1]  = shape1[7:4];   assign ury[1]  = shape1[3:0];
assign shape_layer[2]  = shape2[18:16];   assign llx[2]  = shape2[15:12];   assign lly[2]  = shape2[11:8];   assign urx[2]  = shape2[7:4];   assign ury[2]  = shape2[3:0];
assign shape_layer[3]  = shape3[18:16];   assign llx[3]  = shape3[15:12];   assign lly[3]  = shape3[11:8];   assign urx[3]  = shape3[7:4];   assign ury[3]  = shape3[3:0];
assign shape_layer[4]  = shape4[18:16];   assign llx[4]  = shape4[15:12];   assign lly[4]  = shape4[11:8];   assign urx[4]  = shape4[7:4];   assign ury[4]  = shape4[3:0];
assign shape_layer[5]  = shape5[18:16];   assign llx[5]  = shape5[15:12];   assign lly[5]  = shape5[11:8];   assign urx[5]  = shape5[7:4];   assign ury[5]  = shape5[3:0];
assign shape_layer[6]  = shape6[18:16];   assign llx[6]  = shape6[15:12];   assign lly[6]  = shape6[11:8];   assign urx[6]  = shape6[7:4];   assign ury[6]  = shape6[3:0];
assign shape_layer[7]  = shape7[18:16];   assign llx[7]  = shape7[15:12];   assign lly[7]  = shape7[11:8];   assign urx[7]  = shape7[7:4];   assign ury[7]  = shape7[3:0];
assign shape_layer[8]  = shape8[18:16];   assign llx[8]  = shape8[15:12];   assign lly[8]  = shape8[11:8];   assign urx[8]  = shape8[7:4];   assign ury[8]  = shape8[3:0];
assign shape_layer[9]  = shape9[18:16];   assign llx[9]  = shape9[15:12];   assign lly[9]  = shape9[11:8];   assign urx[9]  = shape9[7:4];   assign ury[9]  = shape9[3:0];
assign shape_layer[10] = shape10[18:16];  assign llx[10] = shape10[15:12];  assign lly[10] = shape10[11:8];  assign urx[10] = shape10[7:4];  assign ury[10] = shape10[3:0];
assign shape_layer[11] = shape11[18:16];  assign llx[11] = shape11[15:12];  assign lly[11] = shape11[11:8];  assign urx[11] = shape11[7:4];  assign ury[11] = shape11[3:0];
assign shape_layer[12] = shape12[18:16];  assign llx[12] = shape12[15:12];  assign lly[12] = shape12[11:8];  assign urx[12] = shape12[7:4];  assign ury[12] = shape12[3:0];
assign shape_layer[13] = shape13[18:16];  assign llx[13] = shape13[15:12];  assign lly[13] = shape13[11:8];  assign urx[13] = shape13[7:4];  assign ury[13] = shape13[3:0];
assign shape_layer[14] = shape14[18:16];  assign llx[14] = shape14[15:12];  assign lly[14] = shape14[11:8];  assign urx[14] = shape14[7:4];  assign ury[14] = shape14[3:0];
assign shape_layer[15] = shape15[18:16];  assign llx[15] = shape15[15:12];  assign lly[15] = shape15[11:8];  assign urx[15] = shape15[7:4];  assign ury[15] = shape15[3:0];
// unpack DRC rule
assign rule_type = drc_sel[0]; // LSB indicates rule type
assign rule_layer = drc_sel[3:1]; // MSBs indicate layer for width/spacing rules

// get rule value mode (depends on rule type and rule layer)
RuleValMode_Decoder rvm_decoder (
    // .rule_type(rule_type),
    // .rule_layer(rule_layer),
    // .rule_val_mode(rvm)
    .drc_sel(drc_sel),
    .en_violate(en_violate)
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
    trans_rule_layer = rule_layer + 1;
    // casez(rule_layer)
    //     3'd0: trans_rule_layer = 3'd1; // CO
    //     3'd1: trans_rule_layer = 3'd2; // OD
    //     3'd2: trans_rule_layer = 3'd3; // PO
    //     3'd3: trans_rule_layer = 3'd4; // M1
    //     3'd4: trans_rule_layer = 3'd5; // NP
    //     3'd5: trans_rule_layer = 3'd6; // PP
    //     3'd6: trans_rule_layer = 3'd7; // NW
    //     default: trans_rule_layer = 3'bx;
    // endcase
end

// check which shapes are on the same layer as the rule_layer, store in is_layer_2_Check
genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : check_layer
        assign is_layer_2_Check[i] = (shape_layer[i] == trans_rule_layer);
    end
endgenerate

// 1D masks for factored grid construction (reduces per-cell comparators)
wire [14:0] x_in_range [0:15]; // x_in_range[s][k] = is_layer_2_Check[s] & (llx[s] <= k) & (urx[s] > k)
wire [14:0] y_in_range [0:15]; // y_in_range[s][k] = (lly[s] <= k) & (ury[s] > k)

genvar j;
generate
    for (i = 0; i < 16; i = i + 1) begin : gen_1d_masks
        for (j = 0; j < 15; j = j + 1) begin : gen_x_bits
            assign x_in_range[i][j] = is_layer_2_Check[i] & (llx[i] <= j) & (urx[i] > j);
        end
        for (j = 0; j < 15; j = j + 1) begin : gen_y_bits
            assign y_in_range[i][j] = (lly[i] <= j) & (ury[i] > j);
        end
    end
endgenerate

// Row/column shape masks let each cell use one 16-bit AND + reduction OR.
wire [15:0] row_shape_mask [0:14];
wire [15:0] col_shape_mask [0:14];

generate
    for (j = 0; j < 15; j = j + 1) begin : gen_row_col_masks
        assign row_shape_mask[j] = {
            x_in_range[15][j], x_in_range[14][j], x_in_range[13][j], x_in_range[12][j],
            x_in_range[11][j], x_in_range[10][j], x_in_range[9][j],  x_in_range[8][j],
            x_in_range[7][j],  x_in_range[6][j],  x_in_range[5][j],  x_in_range[4][j],
            x_in_range[3][j],  x_in_range[2][j],  x_in_range[1][j],  x_in_range[0][j]
        };
        assign col_shape_mask[j] = {
            y_in_range[15][j], y_in_range[14][j], y_in_range[13][j], y_in_range[12][j],
            y_in_range[11][j], y_in_range[10][j], y_in_range[9][j],  y_in_range[8][j],
            y_in_range[7][j],  y_in_range[6][j],  y_in_range[5][j],  y_in_range[4][j],
            y_in_range[3][j],  y_in_range[2][j],  y_in_range[1][j],  y_in_range[0][j]
        };
    end
endgenerate

// construct the grid (17x17 with zero-padded borders, original 15x15 content in [1:15][1:15])
generate
    // The outer border rows (0, 16) and columns (bit 0, bit 16) are zero-padded.
    // The original 15x15 content is placed in grid[1..15][1..15].
    // For a shape with llx=0, lly=4, urx=3, ury=10: grid[1..3][5..10] = 1 (shifted by +1).
    for (i = 0; i < 17; i = i + 1) begin : construct_grids
        for (j = 0; j < 17; j = j + 1) begin : construct_grid_bits
            if (i == 0 || i == 16 || j == 0 || j == 16) begin : zero_pad
                assign grid[i][j] = rule_type;//1'b0;
            end else begin : interior
                assign grid[i][j] = (|(row_shape_mask[i-1] & col_shape_mask[j-1])) ^ rule_type;
            end
        end
    end
endgenerate

wire [16:0] grid_tr[0:16]; // a transposed version of grid to facilitate counting vertical violations column by column
// transpose the grid to get grid_tr, so that we can reuse RowModLite to count vertical violations by treating each column as a row
// genvar i, j;
generate
    for (i = 0; i < 17; i = i + 1) begin : transpose_grid
        for (j = 0; j < 17; j = j + 1) begin
            assign grid_tr[i][j] = grid[j][i];
        end
    end
endgenerate

// Pre-compute CheckMask for each row of grid_tr (for horizontal violations)
// 17 instances instead of 32 (one per unique row, shared between adjacent pairs)
wire [14:0] h_cm_v1 [0:16];
wire [13:0] h_cm_v2 [0:16];
wire [12:0] h_cm_v3 [0:16];
wire [11:0] h_cm_v4 [0:16];
generate
    for (i = 0; i < 17; i = i + 1) begin : h_checkmask
        CheckMask cm_h (
            .data_in(grid_tr[i]),
            // .rule_type(rule_type),
            .match_010(h_cm_v1[i]),
            .match_0110(h_cm_v2[i]),
            .match_01110(h_cm_v3[i]),
            .match_011110(h_cm_v4[i])
        );
    end
endgenerate

// Pre-compute CheckMask for each row of grid (for vertical violations)
// 17 instances instead of 32
wire [14:0] v_cm_v1 [0:16];
wire [13:0] v_cm_v2 [0:16];
wire [12:0] v_cm_v3 [0:16];
wire [11:0] v_cm_v4 [0:16];
generate
    for (i = 0; i < 17; i = i + 1) begin : v_checkmask
        CheckMask cm_v (
            .data_in(grid[i]),
            // .rule_type(rule_type),
            .match_010(v_cm_v1[i]),
            .match_0110(v_cm_v2[i]),
            .match_01110(v_cm_v3[i]),
            .match_011110(v_cm_v4[i])
        );
    end
endgenerate

// Connect 16 RowModLite for horizontal violations using shared CheckMask results
wire [3:0] h_nv_per_row [0:15];   // one count per adjacent row pair
reg [4:0] h_nv; // total horizontal violations

generate
    for (i = 0; i < 16; i = i + 1) begin : h_row_mods
        RowModLite row_mod_h (
            .match_v1_row1(h_cm_v1[i]),   .match_v2_row1(h_cm_v2[i]),
            .match_v3_row1(h_cm_v3[i]),   .match_v4_row1(h_cm_v4[i]),
            .match_v1_row2(h_cm_v1[i+1]), .match_v2_row2(h_cm_v2[i+1]),
            .match_v3_row2(h_cm_v3[i+1]), .match_v4_row2(h_cm_v4[i+1]),
            // .rvm(rvm),
            .en_violate(en_violate),
            .total_nv(h_nv_per_row[i])
        );
    end
endgenerate

// Flatten the 2D arrays into 64-bit packed buses
wire [63:0] h_nv_packed = {
    h_nv_per_row[15], h_nv_per_row[14], h_nv_per_row[13], h_nv_per_row[12],
    h_nv_per_row[11], h_nv_per_row[10], h_nv_per_row[9],  h_nv_per_row[8],
    h_nv_per_row[7],  h_nv_per_row[6],  h_nv_per_row[5],  h_nv_per_row[4],
    h_nv_per_row[3],  h_nv_per_row[2],  h_nv_per_row[1],  h_nv_per_row[0]
};

// accumulate the total horizontal violations from each row pair
// always @(*) begin
//     h_nv = 0;
//     for (integer k = 0; k < 16; k = k + 1) begin
//         h_nv = h_nv + h_nv_per_row[k];
//     end
// end

// Instantiate the horizontal adder tree
AdderTree16 h_adder_tree (
    .in_flat(h_nv_packed),
    .out_sum(h_nv)
);

// Connect 16 RowModLite for vertical violations using shared CheckMask results
reg [4:0] v_nv; // total vertical violations
wire [3:0] v_nv_per_col [0:15]; // vertical violations per column

generate
    for (i = 0; i < 16; i = i + 1) begin : v_row_mods
        RowModLite row_mod_v (
            .match_v1_row1(v_cm_v1[i]),   .match_v2_row1(v_cm_v2[i]),
            .match_v3_row1(v_cm_v3[i]),   .match_v4_row1(v_cm_v4[i]),
            .match_v1_row2(v_cm_v1[i+1]), .match_v2_row2(v_cm_v2[i+1]),
            .match_v3_row2(v_cm_v3[i+1]), .match_v4_row2(v_cm_v4[i+1]),
            // .rvm(rvm),
            .en_violate(en_violate),
            .total_nv(v_nv_per_col[i])
        );
    end
endgenerate

wire [63:0] v_nv_packed = {
    v_nv_per_col[15], v_nv_per_col[14], v_nv_per_col[13], v_nv_per_col[12],
    v_nv_per_col[11], v_nv_per_col[10], v_nv_per_col[9],  v_nv_per_col[8],
    v_nv_per_col[7],  v_nv_per_col[6],  v_nv_per_col[5],  v_nv_per_col[4],
    v_nv_per_col[3],  v_nv_per_col[2],  v_nv_per_col[1],  v_nv_per_col[0]
};

// accumulate the total vertical violations from each column pair
// always @(*) begin
//     v_nv = 0;
//     for (integer k = 0; k < 16; k = k + 1) begin
//         v_nv = v_nv + v_nv_per_col[k];
//     end
// end

// Instantiate the vertical adder tree
AdderTree16 v_adder_tree (
    .in_flat(v_nv_packed),
    .out_sum(v_nv)
);


assign drc_out = h_nv + v_nv; // total violations = horizontal violations + vertical violations

endmodule
