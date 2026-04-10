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
parameter SORT = 2'd1;
parameter MERGE = 2'd2;
parameter OUTPUT = 2'd3;

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
// the updated weights, computed at MERGE, sent to merge_weights ffs at SORT
reg [4:0] nxt_merge_weights [0:7];

// store the output mode
reg output_mode;

// the index of each input characters and the root of subtrees (formed by merging)
// to preserve input order, we should input {merge_nodes[0], merge_nodes[1], ...m merge_nodes[7]} as IN_character to SORT_IP
// index: 6 and 7 are the 2 smallest, and 7 will become the new subtree root while 6 will be assigned weight=7
reg [3:0] merge_nodes [0:7]; 
reg [3:0] nxt_merge_nodes [0:7];

// stored the huffman code of each input char (in input order)
reg [6:0] huff_code [0:7]; // index: 0->A, 1->B...7->V

// the length of the huffman code of each input char (in input order)
// serve as a counter, represent how many more bits are yet to be output
// reach 0 -> end output of this char, increment main_cnt
reg [2:0] code_len [0:7]; // index: 0->A, 1->B...7->V

// store the index of the A, B, ... V's subtree roots in sorted_nodess
// ex: A's subtree root is sorted_nodes[root_idx[0]]
reg [2:0] root_idx [0:7]; // index: 0->A, 1->B...7->V

// state == WAIT_INPUT: count the number of input weight stored
// state == OUTPUT: count the number of encoded str that has been output
// state == MERGE/SORT: count how many iters of merge has been performed, 
// incremented at the same cycle as when merge comb logic is performed
// Note: when merge_cnt==6, we are left with only 2 subtree roots, the total weight value might overflow but it doesn't matter
reg [2:0] main_cnt;
// the index of the char being output
reg [2:0] out_char_idx;
reg [2:0] nxt_char;
reg nxt_out_code;

// SORT_IP IO wires (IP_WIDTH=8)
// wire [31:0] IN_character;
// wire [39:0] IN_weight;
wire [31:0] raw_sort_out;

// pipelined output char from sorter
reg [3:0] sorted_nodes [0:7];
reg [3:0] nxt_sorted_nodes [0:7];

// reg [2:0] order [0:7];
// reg [2:0] nxt_order [0:7];
// integer k;
// reg [2:0] keep_cnt;

// wire [31:0] sort_in_char;
// wire [39:0] sort_in_weight;

reg [4:0] w6, w7;
reg [2:0] keep_cnt;

integer i, j;
genvar idx;
// ===============================================================
// Design
// ===============================================================
always @(posedge clk or negedge rst_n) begin : main_cnt_ctrl
    if(!rst_n)begin
        main_cnt <= 0;
    end else begin
        case(state)
        WAIT_INPUT: begin
            // we transition to SORT at the last clk edge of in_valid == 1 (main_cnt == 7), 
            // no need to reset counter
            main_cnt <= in_valid ? main_cnt + 1 : 0;
        end
        SORT:begin
            main_cnt <= main_cnt;
        end
        MERGE: begin
            // reset counter to 0 when transitioning to OUTPUT
            main_cnt <= (main_cnt < 6) ? main_cnt + 1 : 0;
        end
        OUTPUT: begin
            // increment when we finish outputing an encoded string
            main_cnt <= code_len[out_char_idx]==1 ? main_cnt + 1 : main_cnt;
        end
        default: main_cnt <= 0;
    endcase
    end
end

always @(*) begin
    if(state == OUTPUT)begin
        if(!output_mode)begin // ILOVE
            case(main_cnt)
            3'd0: out_char_idx = I;
            3'd1: out_char_idx = L;
            3'd2: out_char_idx = O;
            3'd3: out_char_idx = V;
            3'd4: out_char_idx = E;
            default: out_char_idx = 0;
            endcase
        end else begin // ICLAB
            case(main_cnt)
            3'd0: out_char_idx = I;
            3'd1: out_char_idx = C;
            3'd2: out_char_idx = L;
            3'd3: out_char_idx = A;
            3'd4: out_char_idx = B;
            default: out_char_idx = 0;
            endcase
        end
    end else begin
        out_char_idx = 0;
    end
end


always @(*) begin : state_transistion
    case(state)
        WAIT_INPUT: begin
            nxt_state = (main_cnt==7) ? SORT : WAIT_INPUT;
        end
        SORT: begin
            nxt_state = MERGE;
        end 
        MERGE: begin
            nxt_state = (main_cnt==6) ? OUTPUT : SORT;
        end
        OUTPUT: begin
            // when we have output the last bit of the fifth char
            if(main_cnt==4 && code_len[out_char_idx]==1)begin
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

// TODO: seperate weight storage and the reordered weight sent to sorter to prevent confusion
always @(*) begin : nxt_merge_weights_logic
    // Default: hold current values
    for(i=0; i<8; i=i+1) begin
        nxt_merge_weights[i] = merge_weights[i];
        nxt_merge_nodes[i]   = merge_nodes[i];
    end
    w6 = 0; 
    w7 = 0;

    if (state == WAIT_INPUT && in_valid) begin
        // Shift in new weights
        nxt_merge_weights[7] = in_weight;
        for(i=0; i<7; i=i+1) begin
            nxt_merge_weights[i] = merge_weights[i+1];
        end
        // Note: merge_nodes remains unchanged during WAIT_INPUT
    end else if (state == MERGE) begin
        // 1. Extract weights of the two nodes to be merged
        for(i=0; i<8; i=i+1) begin
            if (merge_nodes[i] == sorted_nodes[6]) w6 = merge_weights[i];
            if (merge_nodes[i] == sorted_nodes[7]) w7 = merge_weights[i];
        end

        // 2. Compress the array: shift surviving nodes to the front
        // This preserves their relative priority for the stable sort
        keep_cnt = 0;
        for(i=0; i<8; i=i+1) begin
            if (merge_nodes[i] != sorted_nodes[6] && merge_nodes[i] != sorted_nodes[7]) begin
                nxt_merge_nodes[keep_cnt]   = merge_nodes[i];
                nxt_merge_weights[keep_cnt] = merge_weights[i];
                keep_cnt = keep_cnt + 1;
            end
        end

        // 3. Append the new subtree to the end of the valid elements (index 6)
        // Reuse sorted_nodes[7] as the ID for the new subtree
        nxt_merge_nodes[6]   = sorted_nodes[7];
        nxt_merge_weights[6] = w6 + w7;

        // 4. Invalidate the discarded node and move it to the last position (index 7)
        nxt_merge_nodes[7]   = 4'd15;
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
    .IN_character({merge_nodes[0], merge_nodes[1], merge_nodes[2], merge_nodes[3],
                    merge_nodes[4], merge_nodes[5], merge_nodes[6], merge_nodes[7]}),
    .OUT_character(raw_sort_out),
    .IN_weight({merge_weights[0], merge_weights[1], merge_weights[2], merge_weights[3],
                merge_weights[4], merge_weights[5], merge_weights[6], merge_weights[7]})
);

// combinationally unpack sorter output to next-state array (order preserved)
generate
    for(idx=0;idx<8;idx=idx+1)begin
        always @(*) begin : nxt_sorted_nodes_unpack
            nxt_sorted_nodes[7-idx] = raw_sort_out[4*idx+3:4*idx];
        end
    end
endgenerate

// place pipeline regs at the sorter outputs
generate
    for(idx=0;idx<8;idx=idx+1)begin
        always @(posedge clk or negedge rst_n) begin : pipeline_sorter_outputs
            if(!rst_n)begin
                sorted_nodes[idx] <= 0;
            end else begin
                sorted_nodes[idx] <= nxt_sorted_nodes[idx];
            end
        end
    end
endgenerate


always @(posedge clk or negedge rst_n) begin : code_len_ctrl
    if(!rst_n)begin
        for(i=0;i<8;i=i+1)begin
            code_len[i] <= 0;
        end
    end else begin
        if(state==MERGE)begin
            for(i=0;i<8;i=i+1)begin
                if(root_idx[i] == sorted_nodes[6] || root_idx[i] == sorted_nodes[7])begin
                    code_len[i] <= code_len[i] + 1;
                end
            end
        end else if(state == OUTPUT)begin
            code_len[out_char_idx] <= (code_len[out_char_idx]==0) ? 0 : code_len[out_char_idx]-1;
        end else if(state == WAIT_INPUT)begin
            for(i=0;i<8;i=i+1)begin
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
        for(i=0;i<8;i=i+1)begin // i: orig char idx, A, B ... V
            if(root_idx[i] == sorted_nodes[6])begin // bigger, insert 0
                huff_code[i] <= {1'b0, huff_code[i][6:1]};
                // huff_code[i][code_len[i]] <= 0;
            end else if(root_idx[i] == sorted_nodes[7])begin // smaller, insert 1
                // huff_code[i][code_len[i]] <= 1;
                huff_code[i] <= {1'b1, huff_code[i][6:1]};
            end
        end
    end else if (state == OUTPUT) begin
        // OUTPUT: shift left to output the next bit at the MSB position
        if (code_len[out_char_idx] != 0) begin
            huff_code[out_char_idx] <= {huff_code[out_char_idx][5:0], 1'b0};
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

// root_idx stores indexes of the original input order, so does sorted_nodes
always @(posedge clk or negedge rst_n) begin : root_idx_ctrl
    if(!rst_n)begin
        root_idx[A] <= A;
        root_idx[B] <= B;
        root_idx[C] <= C;
        root_idx[E] <= E;
        root_idx[I] <= I;
        root_idx[L] <= L;
        root_idx[O] <= O;
        root_idx[V] <= V;
    end else if(state == WAIT_INPUT) begin
        root_idx[A] <= A;
        root_idx[B] <= B;
        root_idx[C] <= C;
        root_idx[E] <= E;
        root_idx[I] <= I;
        root_idx[L] <= L;
        root_idx[O] <= O;
        root_idx[V] <= V;
    end else if(state==MERGE)begin
        for(i=0;i<8;i=i+1)begin // i: orig char idx, A, B ... V
            if(root_idx[i] == sorted_nodes[6] || root_idx[i] == sorted_nodes[7])begin
                root_idx[i] <= sorted_nodes[7];
            end
        end
    end
end

// forwarding logic for huff_code[I][6] at the first cycle of OUTPUT state
reg forward_out_code;
always @(*) begin : forward_out_code_logic
    if(root_idx[I] == sorted_nodes[6]) forward_out_code = 0;
    else if(root_idx[I] == sorted_nodes[7]) forward_out_code = 1;
    else forward_out_code = huff_code[I][6];
end

always @(posedge clk or negedge rst_n) begin : output_ctrl
    if(!rst_n) begin
        out_valid <= 1'b0;
        out_code  <= 1'b0;
    end else begin
        if(nxt_state == OUTPUT) begin
            out_valid <= 1'b1;
            out_code  <= nxt_out_code;
        end else begin
            out_valid <= 1'b0;
            out_code  <= 1'b0;
        end
    end
end

// Predict the character to be output in the next cycle
always @(*) begin : nxt_char_logic
    if (state == MERGE && nxt_state == OUTPUT) begin
        nxt_char = I;
    end else if (state == OUTPUT && nxt_state == OUTPUT) begin
        if (code_len[out_char_idx] == 1) begin
            // Move to next character
            if (!output_mode) begin // ILOVE
                case(main_cnt)
                    3'd0: nxt_char = L;
                    3'd1: nxt_char = O;
                    3'd2: nxt_char = V;
                    3'd3: nxt_char = E;
                    default: nxt_char = I;
                endcase
            end else begin // ICLAB
                case(main_cnt)
                    3'd0: nxt_char = C;
                    3'd1: nxt_char = L;
                    3'd2: nxt_char = A;
                    3'd3: nxt_char = B;
                    default: nxt_char = I;
                endcase
            end
        end else begin
            // Continue current character
            nxt_char = out_char_idx;
        end
    end else begin
        nxt_char = I;
    end
end

// Determine the exact bit for the next cycle
always @(*) begin : nxt_out_code_logic
    if (state == MERGE && nxt_state == OUTPUT) begin
        // The very first bit is computed directly from the current merge
        if (root_idx[I] == sorted_nodes[6]) nxt_out_code = 1'b0;
        else if (root_idx[I] == sorted_nodes[7]) nxt_out_code = 1'b1;
        else nxt_out_code = huff_code[I][6]; // Fallback
    end else if (state == OUTPUT) begin
        if (nxt_char == out_char_idx) begin
            // Continuing same char: it will shift left at this posedge, 
            // so the next bit to latch is at [5]
            nxt_out_code = huff_code[nxt_char][5];
        end else begin
            // Starting new char: it does not shift at this posedge, 
            // so the first bit to latch is at [6]
            nxt_out_code = huff_code[nxt_char][6];
        end
    end else begin
        nxt_out_code = 1'b0;
    end
end

// assign out_valid = (state == OUTPUT);
// assign out_code = (state == OUTPUT) ? huff_code[out_char_idx][6] : 1'b0;
// assign out_code = (state == OUTPUT) ? huff_code[out_char_idx][code_len[out_char_idx]-1] : 0;
// always @(posedge clk or negedge rst_n) begin : output_ctrl
//     if(!rst_n)begin
//         out_code <= 0;
//         // out_valid <= 0;
//     end else begin
//         if(state == OUTPUT)begin
//             out_code <= huff_code[out_char_idx][code_len[out_char_idx]-1];
            
//         end else begin
//             out_code <= 0;
//             // out_valid <= 0;
//         end

//     end
// end


endmodule