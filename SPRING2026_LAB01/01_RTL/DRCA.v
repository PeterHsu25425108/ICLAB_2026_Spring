// comparator unit for DRC-A
module CoorComp(
    input [4:0] ele1, // MSB: valid bit, LSBs: shape coordinates
    input [4:0] ele2,
    // compare the coordinates of ele1 and ele2, output the bigger one and smaller one
    output reg [4:0] big_ele,
    output reg [4:0] small_ele
);

always @(*) begin
    if (ele1 > ele2) begin
        big_ele = ele1;
        small_ele = ele2;
    end else begin
        big_ele = ele2;
        small_ele = ele1;
    end
end
endmodule

// The order of the outputs: descending order
module Sorter8 (
    input  [4:0] in0, in1, in2, in3, in4, in5, in6, in7,
    output [4:0] out0, out1, out2, out3, out4, out5, out6, out7
);
    // Stage 1
    wire [4:0] a0, a1, a2, a3, a4, a5, a6, a7;
    CoorComp c1_0(.ele1(in0), .ele2(in1), .big_ele(a0), .small_ele(a1));
    CoorComp c1_1(.ele1(in2), .ele2(in3), .big_ele(a2), .small_ele(a3));
    CoorComp c1_2(.ele1(in4), .ele2(in5), .big_ele(a4), .small_ele(a5));
    CoorComp c1_3(.ele1(in6), .ele2(in7), .big_ele(a6), .small_ele(a7));

    // Stage 2
    wire [4:0] b0, b1, b2, b3, b4, b5, b6, b7;
    CoorComp c2_0(.ele1(a0), .ele2(a2), .big_ele(b0), .small_ele(b2));
    CoorComp c2_1(.ele1(a1), .ele2(a3), .big_ele(b1), .small_ele(b3));
    CoorComp c2_2(.ele1(a4), .ele2(a6), .big_ele(b4), .small_ele(b6));
    CoorComp c2_3(.ele1(a5), .ele2(a7), .big_ele(b5), .small_ele(b7));

    // Stage 3
    wire [4:0] c1, c2, c5, c6;
    CoorComp c3_0(.ele1(b1), .ele2(b2), .big_ele(c1), .small_ele(c2));
    CoorComp c3_1(.ele1(b5), .ele2(b6), .big_ele(c5), .small_ele(c6));
    wire [4:0] c0 = b0, c3 = b3, c4 = b4, c7 = b7;

    // Stage 4
    wire [4:0] d0, d1, d2, d3, d4, d5, d6, d7;
    CoorComp c4_0(.ele1(c0), .ele2(c4), .big_ele(d0), .small_ele(d4));
    CoorComp c4_1(.ele1(c1), .ele2(c5), .big_ele(d1), .small_ele(d5));
    CoorComp c4_2(.ele1(c2), .ele2(c6), .big_ele(d2), .small_ele(d6));
    CoorComp c4_3(.ele1(c3), .ele2(c7), .big_ele(d3), .small_ele(d7));

    // Stage 5
    wire [4:0] e2, e3, e4, e5;
    CoorComp c5_0(.ele1(d2), .ele2(d4), .big_ele(e2), .small_ele(e4));
    CoorComp c5_1(.ele1(d3), .ele2(d5), .big_ele(e3), .small_ele(e5));
    wire [4:0] e0 = d0, e1 = d1, e6 = d6, e7 = d7;

    // Stage 6
    wire [4:0] f1, f2, f3, f4, f5, f6;
    CoorComp c6_0(.ele1(e1), .ele2(e2), .big_ele(f1), .small_ele(f2));
    CoorComp c6_1(.ele1(e3), .ele2(e4), .big_ele(f3), .small_ele(f4));
    CoorComp c6_2(.ele1(e5), .ele2(e6), .big_ele(f5), .small_ele(f6));

    // Final Outputs
    assign out0 = e0;
    assign out1 = f1;
    assign out2 = f2;
    assign out3 = f3;
    assign out4 = f4;
    assign out5 = f5;
    assign out6 = f6;
    assign out7 = e7;
endmodule

module Top8_Selector (
    input  [4:0] in0, in1, in2, in3, in4, in5, in6, in7,
    input  [4:0] in8, in9, in10, in11, in12, in13, in14, in15,
    output [4:0] top0, top1, top2, top3, top4, top5, top6, top7
);
    // Sorter outputs
    wire [4:0] sa0, sa1, sa2, sa3, sa4, sa5, sa6, sa7;
    wire [4:0] sb0, sb1, sb2, sb3, sb4, sb5, sb6, sb7;

    // Sort the first 8 inputs
    Sorter8 sorter_A (
        .in0(in0), .in1(in1), .in2(in2), .in3(in3), .in4(in4), .in5(in5), .in6(in6), .in7(in7),
        .out0(sa0), .out1(sa1), .out2(sa2), .out3(sa3), .out4(sa4), .out5(sa5), .out6(sa6), .out7(sa7)
    );

    // Sort the next 8 inputs
    Sorter8 sorter_B (
        .in0(in8), .in1(in9), .in2(in10), .in3(in11), .in4(in12), .in5(in13), .in6(in14), .in7(in15),
        .out0(sb0), .out1(sb1), .out2(sb2), .out3(sb3), .out4(sb4), .out5(sb5), .out6(sb6), .out7(sb7)
    );

    // Merge Stage 1: Compare top half with bottom half.
    // We reverse the outputs of Sorter B (pairing sa0 with sb7, sa1 with sb6...) to form a bitonic sequence.
    wire [4:0] m1_0_b, m1_1_b, m1_2_b, m1_3_b, m1_4_b, m1_5_b, m1_6_b, m1_7_b;

    // substitide CoorComp with direct assignments since we only care about the bigger elements
    assign m1_0_b = (sa0 > sb7) ? sa0 : sb7;
    assign m1_1_b = (sa1 > sb6) ? sa1 : sb6;
    assign m1_2_b = (sa2 > sb5) ? sa2 : sb5;
    assign m1_3_b = (sa3 > sb4) ? sa3 : sb4;
    assign m1_4_b = (sa4 > sb3) ? sa4 : sb3;
    assign m1_5_b = (sa5 > sb2) ? sa5 : sb2;
    assign m1_6_b = (sa6 > sb1) ? sa6 : sb1;
    assign m1_7_b = (sa7 > sb0) ? sa7 : sb0;

    // Merge Stage 2: Distance 4
    wire [4:0] m2_0_b, m2_0_s, m2_1_b, m2_1_s, m2_2_b, m2_2_s, m2_3_b, m2_3_s;
    
    CoorComp m2_c0(.ele1(m1_0_b), .ele2(m1_4_b), .big_ele(m2_0_b), .small_ele(m2_0_s));
    CoorComp m2_c1(.ele1(m1_1_b), .ele2(m1_5_b), .big_ele(m2_1_b), .small_ele(m2_1_s));
    CoorComp m2_c2(.ele1(m1_2_b), .ele2(m1_6_b), .big_ele(m2_2_b), .small_ele(m2_2_s));
    CoorComp m2_c3(.ele1(m1_3_b), .ele2(m1_7_b), .big_ele(m2_3_b), .small_ele(m2_3_s));

    // Merge Stage 3: Distance 2
    wire [4:0] m3_0_b, m3_0_s, m3_1_b, m3_1_s, m3_2_b, m3_2_s, m3_3_b, m3_3_s;
    
    CoorComp m3_c0(.ele1(m2_0_b), .ele2(m2_2_b), .big_ele(m3_0_b), .small_ele(m3_0_s));
    CoorComp m3_c1(.ele1(m2_1_b), .ele2(m2_3_b), .big_ele(m3_1_b), .small_ele(m3_1_s));
    CoorComp m3_c2(.ele1(m2_0_s), .ele2(m2_2_s), .big_ele(m3_2_b), .small_ele(m3_2_s));
    CoorComp m3_c3(.ele1(m2_1_s), .ele2(m2_3_s), .big_ele(m3_3_b), .small_ele(m3_3_s));

    // Merge Stage 4: Distance 1 (Final sorted top 8 outputs)
    CoorComp m4_c0(.ele1(m3_0_b), .ele2(m3_1_b), .big_ele(top0), .small_ele(top1));
    CoorComp m4_c1(.ele1(m3_0_s), .ele2(m3_1_s), .big_ele(top2), .small_ele(top3));
    CoorComp m4_c2(.ele1(m3_2_b), .ele2(m3_3_b), .big_ele(top4), .small_ele(top5));
    CoorComp m4_c3(.ele1(m3_2_s), .ele2(m3_3_s), .big_ele(top6), .small_ele(top7));

endmodule

module FilterSort(
    input [2:0] rule_layer,
    input [2:0] shape_layer [0:15],
    input [3:0] shape_coor[0:15],
    output keep_shape [0:7], // 1: the shape belongs to the same layer as rule_layer, 0: otherwise
    output [3:0] sort_coor [0:7]
);
// output the <= 8 shapes of the same layer
wire [4:0] ele_filtered [0:15]; // MSB: Whether this shape belongs to rule_layer, LSBs (4bits): shape coordinates
wire [4:0] sort_ele [0:7]; // outputs from Top8_Selector, MSB: valid bit, LSBs: shape coordinates

genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : expand_ele_filtered
        assign ele_filtered[i] = (rule_layer == shape_layer[i]) ? {1'b1, shape_coor[i]} : 5'd0;
    end
endgenerate

// Use Top8_Selector to select the top 8 shapes of the same layer
Top8_Selector top8_selector (
    .in0(ele_filtered[0]), .in1(ele_filtered[1]), .in2(ele_filtered[2]), .in3(ele_filtered[3]), .in4(ele_filtered[4]), 
    .in5(ele_filtered[5]), .in6(ele_filtered[6]), .in7(ele_filtered[7]), .in8(ele_filtered[8]), .in9(ele_filtered[9]),
    .in10(ele_filtered[10]), .in11(ele_filtered[11]), .in12(ele_filtered[12]), .in13(ele_filtered[13]), 
    .in14(ele_filtered[14]), .in15(ele_filtered[15]),
    .top0(sort_ele[0]), .top1(sort_ele[1]), .top2(sort_ele[2]), .top3(sort_ele[3]), .top4(sort_ele[4]), 
    .top5(sort_ele[5]), .top6(sort_ele[6]), .top7(sort_ele[7])
);

// unpack the outputs of Top8_Selector
genvar j;
generate
    for (j = 0; j < 8; j = j + 1) begin : unpack_sort_outputs
        assign keep_shape[j] = sort_ele[j][4]; // valid bit
        assign sort_coor[j] = sort_ele[j][3:0]; // shape coordinates
    end
endgenerate

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

wire keep_shape [0:7]; // from FilterSort, indicates whether the shape belongs to the same layer as rule_layer
wire [3:0] sort_llx [0:7]; // from FilterSort,
wire [3:0] sort_lly [0:7]
;//**************************************************
// Design 
//**************************************************
// unpack input shapes
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

FilterSort filter_sort_x (
    .rule_layer(rule_layer),
    .shape_layer(shape_layer),
    .shape_coor(llx), // pack the coordinates into 4 bits for each shape
    .keep_shape(keep_shape), // not used in this design, can be connected to something if needed
    .sort_coor(sort_llx) // not used in this design, can be connected to something if needed
);

FilterSort filter_sort_y (
    .rule_layer(rule_layer),
    .shape_layer(shape_layer),
    .shape_coor(lly), // pack the coordinates into 4 bits for each shape
    .keep_shape(keep_shape), // not used in this design, can be connected to something if needed
    .sort_coor(sort_lly) // not used in this design, can be connected to something if needed
);

assign drc_out = 5'b0;

endmodule
