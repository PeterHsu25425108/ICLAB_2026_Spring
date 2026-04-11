//synopsys translate_off
`include "SORT_IP.v"
//synopsys translate_on

// SORT_IP order:
// MSB -> LSB: large weight->small weight / A>B>C....>V> old subtree > new subtree

module HT(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_weight, 
	out_mode,
    // Output signals
    out_valid, 
	out_code
);

// ============================================
// states
// ============================================
parameter WAIT_INPUT = 2'd0;
parameter MERGE = 2'd1;
parameter OUTPUT = 2'd2;

// ============================================
// input character indexes
// ============================================
parameter A = 0;
parameter B = 1;
parameter C = 2;
parameter E = 3;
parameter I = 4;
parameter L = 5;
parameter O = 6;
parameter V = 7;
// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid, out_mode;
input [2:0] in_weight;

output reg out_code;
output reg out_valid;

// ===============================================================
// Reg & Wire Declaration
// ===============================================================
// states
reg [1:0] state, nxt_state;

// input storage order (0->7): A->B->C->E->I->L->O->V
// the weight of each input characters
// indexed by merge_nodes[2:0]
reg [4:0] merge_weights [0:7];
// the updated weights, computed at MERGE and committed at next clk
reg [4:0] nxt_merge_weights [0:7];

// store the output mode
reg output_mode;

// the index of each input characters and the root of subtrees (formed by merging)
// to preserve input order, we should input {merge_nodes[0], merge_nodes[1], ...m merge_nodes[7]} as IN_character to SORT_IP
// index: 6 and 7 are the 2 smallest, and 7 will become the new subtree root while 6 will be assigned weight=7
reg [2:0] merge_nodes [0:7]; 
reg [2:0] nxt_merge_nodes [0:7];

reg [6:0] huff_code [0:4];
reg [2:0] code_len  [0:4];
reg [2:0] root_idx  [0:4];

// state == WAIT_INPUT: count the number of input weight stored
// state == OUTPUT: count the number of encoded str that has been output
// state == MERGE: count how many iters of merge has been performed,
// incremented at the same cycle as when merge comb logic is performed
// Note: when merge_cnt==6, we are left with only 2 subtree roots, the total weight value might overflow but it doesn't matter
reg [2:0] main_cnt;
// the index of the char being output
reg [2:0] out_char_idx;
// reg [2:0] nxt_char;
// reg nxt_out_code;

// SORT_IP IO wires (IP_WIDTH=8)
// wire [31:0] IN_character;
// wire [39:0] IN_weight;
wire [31:0] raw_sort_out;

// direct combinational sorter outputs for state-folded merge
wire [3:0] curr_sorted_nodes [0:7];

// reg [2:0] order [0:7];
// reg [2:0] nxt_order [0:7];
// integer k;
// reg [2:0] keep_cnt;

// wire [31:0] sort_in_char;
// wire [39:0] sort_in_weight;

wire [4:0] w6, w7;
reg [2:0] keep_cnt;
wire [1:0] drop_cnt [0:7];
// Shared compare signals against current merge targets from sorter
wire [4:0] root_eq6, root_eq7, root_hit67;
wire [7:0] merge_eq6, merge_eq7, merge_hit67, merge_keep67, merge_neq6, merge_neq7;

integer i;
genvar idx;

generate
    for(idx=0; idx<5; idx=idx+1) begin : root_cmp_signals
        assign root_eq6[idx]  = (root_idx[idx] == curr_sorted_nodes[6][2:0]);
        assign root_eq7[idx]  = (root_idx[idx] == curr_sorted_nodes[7][2:0]);
    end

    for(idx=0; idx<8; idx=idx+1) begin : merge_cmp_signals
        assign merge_eq6[idx]  = (merge_nodes[idx] == curr_sorted_nodes[6][2:0]);
        assign merge_eq7[idx]  = (merge_nodes[idx] == curr_sorted_nodes[7][2:0]);
    end

endgenerate
assign root_hit67 = root_eq6 | root_eq7;
assign merge_hit67  = merge_eq6 | merge_eq7;
assign merge_keep67 = ~merge_hit67;
assign merge_neq6   = ~merge_eq6;
assign merge_neq7   = ~merge_eq7;


// ===============================================================
// Design
// ===============================================================
always @(posedge clk or negedge rst_n) begin : main_cnt_ctrl
    if(!rst_n)begin
        main_cnt <= 0;
    end else begin
        case(state)
        WAIT_INPUT: begin
            // we transition to MERGE at the last clk edge of in_valid == 1 (main_cnt == 7),
            // no need to reset counter
            main_cnt <= in_valid ? main_cnt + 1 : 0;
        end
        MERGE: begin
            // reset counter to 0 when transitioning to OUTPUT
            main_cnt <= (main_cnt < 6) ? main_cnt + 1 : 0;
        end
        OUTPUT: begin
            // increment when we finish outputing an encoded string
            main_cnt <= code_len[main_cnt]==1 ? main_cnt + 1 : main_cnt;
        end
        default: main_cnt <= 0;
    endcase
    end
end

// always @(*) begin
//     if(state == OUTPUT)begin
//         if(!output_mode)begin // ILOVE
//             case(main_cnt)
//             3'd0: out_char_idx = I;
//             3'd1: out_char_idx = L;
//             3'd2: out_char_idx = O;
//             3'd3: out_char_idx = V;
//             3'd4: out_char_idx = E;
//             default: out_char_idx = 0;
//             endcase
//         end else begin // ICLAB
//             case(main_cnt)
//             3'd0: out_char_idx = I;
//             3'd1: out_char_idx = C;
//             3'd2: out_char_idx = L;
//             3'd3: out_char_idx = A;
//             3'd4: out_char_idx = B;
//             default: out_char_idx = 0;
//             endcase
//         end
//     end else begin
//         out_char_idx = 0;
//     end
// end


always @(*) begin : state_transistion
    case(state)
        WAIT_INPUT: begin
            nxt_state = (main_cnt==7) ? MERGE : WAIT_INPUT;
        end 
        MERGE: begin
            nxt_state = (main_cnt==6) ? OUTPUT : MERGE;
        end
        OUTPUT: begin
            // when we have output the last bit of the fifth char
            if(main_cnt==4 && code_len[main_cnt]==1)begin
                nxt_state = WAIT_INPUT;
            end else begin 
                nxt_state = OUTPUT;
            end
        end
        default: nxt_state = WAIT_INPUT;
    endcase

end

always @(posedge clk or negedge rst_n) begin : state_seq
    if(!rst_n)begin
        state <= WAIT_INPUT;
    end else begin
        state <= nxt_state;
    end
end

assign w6 = ({5{merge_eq6[0]}} & merge_weights[0]) |
     ({5{merge_eq6[1]}} & merge_weights[1]) |
     ({5{merge_eq6[2]}} & merge_weights[2]) |
     ({5{merge_eq6[3]}} & merge_weights[3]) |
     ({5{merge_eq6[4]}} & merge_weights[4]) |
     ({5{merge_eq6[5]}} & merge_weights[5]) |
     ({5{merge_eq6[6]}} & merge_weights[6]) |
     ({5{merge_eq6[7]}} & merge_weights[7]);

assign w7 = ({5{merge_eq7[0]}} & merge_weights[0]) |
     ({5{merge_eq7[1]}} & merge_weights[1]) |
     ({5{merge_eq7[2]}} & merge_weights[2]) |
     ({5{merge_eq7[3]}} & merge_weights[3]) |
     ({5{merge_eq7[4]}} & merge_weights[4]) |
     ({5{merge_eq7[5]}} & merge_weights[5]) |
     ({5{merge_eq7[6]}} & merge_weights[6]) |
     ({5{merge_eq7[7]}} & merge_weights[7]);

assign drop_cnt[0] = 2'd0;
assign drop_cnt[1] = {1'b0, merge_hit67[0]};
assign drop_cnt[2] = drop_cnt[1] + {1'b0, merge_hit67[1]};
assign drop_cnt[3] = drop_cnt[2] + {1'b0, merge_hit67[2]};
assign drop_cnt[4] = drop_cnt[3] + {1'b0, merge_hit67[3]};
assign drop_cnt[5] = drop_cnt[4] + {1'b0, merge_hit67[4]};
assign drop_cnt[6] = drop_cnt[5] + {1'b0, merge_hit67[5]};
assign drop_cnt[7] = drop_cnt[6] + {1'b0, merge_hit67[6]};

always @(*) begin : nxt_merge_weights_logic
    // Default: hold current values
    for(i=0; i<8; i=i+1) begin
        nxt_merge_weights[i] = merge_weights[i];
        nxt_merge_nodes[i]   = merge_nodes[i];
    end
    // w6 = 0; 
    // w7 = 0;

    if (state == WAIT_INPUT && in_valid) begin
        // Shift in new weights
        nxt_merge_weights[7] = in_weight;
        for(i=0; i<7; i=i+1) begin
            nxt_merge_weights[i] = merge_weights[i+1];
        end
        // Note: merge_nodes remains unchanged during WAIT_INPUT
    end else if (state == MERGE) begin
        // 1. Extract weights of the two nodes to be merged
        // for(i=0; i<8; i=i+1) begin
        //     if (merge_eq6[i]) w6 = merge_weights[i];
        //     if (merge_eq7[i]) w7 = merge_weights[i];
        // end

        // 2. Compress the array: shift surviving nodes to the front
        // This preserves their relative priority for the stable sort
        // keep_cnt = 0;
        // for(i=0; i<8; i=i+1) begin
        //     if (merge_keep67[i]) begin
        //         nxt_merge_nodes[keep_cnt]   = merge_nodes[i];
        //         nxt_merge_weights[keep_cnt] = merge_weights[i];
        //         keep_cnt = keep_cnt + 1;
        //     end
        // end
        for(i=0; i<8; i=i+1) begin
            nxt_merge_nodes[i]   = merge_nodes[i];
            nxt_merge_weights[i] = merge_weights[i];
        end 

        for(i=0; i<6; i=i+1) begin
            // stay at the same position
            if (merge_keep67[i] && drop_cnt[i] == 2'd0) begin
                nxt_merge_nodes[i]   = merge_nodes[i];
                nxt_merge_weights[i] = merge_weights[i];
            end
            // shift 1 position from the right
            else if (merge_keep67[i+1] && drop_cnt[i+1] == 2'd1) begin
                nxt_merge_nodes[i]   = merge_nodes[i+1];
                nxt_merge_weights[i] = merge_weights[i+1];
            end
            // shift 2 positions from the right
            else begin
                nxt_merge_nodes[i]   = merge_nodes[i+2];
                nxt_merge_weights[i] = merge_weights[i+2];
            end
        end

        // 3. Append the new subtree to the end of the valid elements (index 6)
        // Reuse curr_sorted_nodes[7] as the ID for the new subtree
        nxt_merge_nodes[6]   = curr_sorted_nodes[7];
        nxt_merge_weights[6] = w6 + w7;

        // 4. Invalidate the discarded node and move it to the last position (index 7)
        nxt_merge_nodes[7]   = curr_sorted_nodes[6];
        nxt_merge_weights[7] = 5'd31;
    end
end


always @(posedge clk or negedge rst_n) begin : char_weight_and_output_mode_ctrl
    if(!rst_n)begin
        output_mode <= 0;
        for(i=0;i<8;i=i+1)begin
            merge_weights[i] <= 0;
        end
    end else begin
        // capture mode at the first valid input cycle
        output_mode <= (state == WAIT_INPUT && in_valid && main_cnt==0) ? out_mode : output_mode;
        for(i=0;i<8;i=i+1)begin
            merge_weights[i] <= nxt_merge_weights[i];
        end
    end
end

// assign sort_in_char = {
//     {1'b0, order[0]}, {1'b0, order[1]}, {1'b0, order[2]}, {1'b0, order[3]},
//     {1'b0, order[4]}, {1'b0, order[5]}, {1'b0, order[6]}, {1'b0, order[7]}
// };

// assign sort_in_weight = {
//     merge_weights[order[0]], merge_weights[order[1]], merge_weights[order[2]], merge_weights[order[3]],
//     merge_weights[order[4]], merge_weights[order[5]], merge_weights[order[6]], merge_weights[order[7]]
// };

SORT_IP #(.IP_WIDTH(8)) sorter(
    .IN_character({{1'b0, merge_nodes[0]}, {1'b0, merge_nodes[1]}, {1'b0, merge_nodes[2]}, {1'b0, merge_nodes[3]},
                  {1'b0, merge_nodes[4]}, {1'b0, merge_nodes[5]}, {1'b0, merge_nodes[6]}, {1'b0, merge_nodes[7]}}),
    .OUT_character(raw_sort_out),
    .IN_weight({merge_weights[0], merge_weights[1], merge_weights[2], merge_weights[3],
                merge_weights[4], merge_weights[5], merge_weights[6], merge_weights[7]})
);
 

// combinationally unpack sorter output (order preserved)
generate
    for(idx=0;idx<8;idx=idx+1)begin
        assign curr_sorted_nodes[7-idx] = raw_sort_out[4*idx+3:4*idx];
    end
endgenerate


always @(posedge clk or negedge rst_n) begin : code_len_ctrl
    if(!rst_n)begin
        for(i=0;i<5;i=i+1)begin
            code_len[i] <= 0;
        end
    end else begin
        if(state==MERGE)begin
            for(i=0;i<5;i=i+1)begin
                if(root_hit67[i])begin
                    code_len[i] <= code_len[i] + 1;
                end
            end
        end else if(state == OUTPUT) begin
            code_len[main_cnt] <= (code_len[main_cnt]==0) ? 0 : code_len[main_cnt]-1;
        end else if(state == WAIT_INPUT)begin
            for(i=0;i<5;i=i+1)begin
                code_len[i] <= 0;
            end
        end
    end
end

// TODO: there might be a better way to insert new bits, ex. shift reg
always @(posedge clk or negedge rst_n) begin : huff_code_ctrl
    if(!rst_n)begin
        for(i=0;i<8;i=i+1)begin
            huff_code[i] <= 0;
        end
    end else if(state == MERGE) begin
        for(i=0;i<5;i=i+1)begin // i: orig char idx, A, B ... V
            // if(root_eq6[i])begin // bigger, insert 0
            //     // huff_code[i] <= {1'b0, huff_code[i][6:1]};
            //     huff_code[i][code_len[i]] <= 0;
            // end else if(root_eq7[i])begin // smaller, insert 1
            //     huff_code[i][code_len[i]] <= 1;
            //     // huff_code[i] <= {1'b1, huff_code[i][6:1]};
            // end
            huff_code[i][code_len[i]] <= !root_eq6[i] || root_eq7[i];
        end
    end
end


always @(posedge clk or negedge rst_n) begin : merge_nodes_ctrl
    if(!rst_n) begin
        merge_nodes[0] <= 0;
        merge_nodes[1] <= 1;
        merge_nodes[2] <= 2;
        merge_nodes[3] <= 3;
        merge_nodes[4] <= 4;
        merge_nodes[5] <= 5;
        merge_nodes[6] <= 6;
        merge_nodes[7] <= 7;
    end else if (state == WAIT_INPUT) begin
        // Lock IDs 0~7 to align with the shifting weights
        merge_nodes[0] <= 0;
        merge_nodes[1] <= 1;
        merge_nodes[2] <= 2;
        merge_nodes[3] <= 3;
        merge_nodes[4] <= 4;
        merge_nodes[5] <= 5;
        merge_nodes[6] <= 6;
        merge_nodes[7] <= 7;
    end else begin
        for(i=0; i<8; i=i+1) begin
            merge_nodes[i] <= nxt_merge_nodes[i];
        end
    end
end

// root_idx stores indexes of the original input order, so does curr_sorted_nodes
always @(posedge clk or negedge rst_n) begin : root_idx_ctrl
    if(!rst_n) begin
        for(i=0; i<5; i=i+1) root_idx[i] <= 0;
    end else if (state == WAIT_INPUT) begin
        root_idx[0] <= 3'd4; // I
        root_idx[1] <= output_mode ? 3'd2 : 3'd5; // C(2) or L(5)
        root_idx[2] <= output_mode ? 3'd5 : 3'd6; // L(5) or O(6)
        root_idx[3] <= output_mode ? 3'd0 : 3'd7; // A(0) or V(7)
        root_idx[4] <= output_mode ? 3'd1 : 3'd3; // B(1) or E(3)
    end else if (state == MERGE) begin
        for(i=0; i<5; i=i+1) begin 
            if(root_hit67[i]) begin
                root_idx[i] <= curr_sorted_nodes[7];
            end
        end
    end
end

always @(*) begin : output_logic
    out_valid = (state == OUTPUT);
    out_code  = (state == OUTPUT) ? huff_code[main_cnt][code_len[main_cnt]-1] : 1'b0;
end


endmodule