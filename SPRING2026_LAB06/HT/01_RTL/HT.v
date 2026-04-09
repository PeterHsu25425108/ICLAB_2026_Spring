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
output out_valid;

// ===============================================================
// Reg & Wire Declaration
// ===============================================================
// states
reg [1:0] state, nxt_state;

// input storage order (0->7): A->B->C->E->I->L->O->V
// the weight of each input characters
// indexed by nodes[2:0]
reg [4:0] char_weights [0:7];
// the updated weights, computed at MERGE, sent to char_weights ffs at SORT
reg [4:0] nxt_weights [0:7];

// store the output mode
reg output_mode;

// the index of each input characters and the root of subtrees (formed by merging)
// to preserve input order, we should input {nodes[0], nodes[1], ...m nodes[7]} as IN_character to SORT_IP
// index: 6 and 7 are the 2 smallest, and 7 will become the new subtree root while 6 will be assigned weight=7
reg [3:0] nodes [0:7]; 
// reg [3:0] nxt_nodes [0:7];

// stored the huffman code of each input char (in input order)
reg [6:0] huff_code [0:7]; // index: 0->A, 1->B...7->V

// the length of the huffman code of each input char (in input order)
// serve as a counter, represent how many more bits are yet to be output
// reach 0 -> end output of this char, increment main_cnt
reg [2:0] code_len [0:7]; // index: 0->A, 1->B...7->V

// store the index of the A, B, ... V's subtree roots in nodes
// ex: A's subtree root is nodes[root_idx[0]]
reg [2:0] root_idx [0:7]; // index: 0->A, 1->B...7->V

// state == WAIT_INPUT: count the number of input weight stored
// state == OUTPUT: count the number of encoded str that has been output
// state == MERGE/SORT: count how many iters of merge has been performed, 
// incremented at the same cycle as when merge comb logic is performed
// Note: when merge_cnt==6, we are left with only 2 subtree roots, the total weight value might overflow but it doesn't matter
reg [2:0] main_cnt;
// the index of the char being output
reg [2:0] out_char_idx;

// SORT_IP IO wires (IP_WIDTH=8)
// wire [31:0] IN_character;
// wire [39:0] IN_weight;
wire [31:0] raw_sort_out;

// pipelined output char from sorter
reg [3:0] sorted_char [0:7];

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
        if(out_mode)begin // ILOVE
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
        default: nxt_state <= WAIT_INPUT;
    endcase

end

always @(posedge clk or negedge rst_n) begin : state_seq
    if(!rst_n)begin
        state <= WAIT_INPUT;
    end else begin
        state <= nxt_state;
    end
end

generate
    for(idx=0;idx<8;idx=idx+1)begin
        always @(*) begin : nxt_weight_logic
            // when main_cnt==6, nxt_weight might overflow but it doesn't matter
            if(state == MERGE /*&& main_cnt <= 6*/)begin
                if(idx==6)begin
                    // discard nodes[6], set highest weight
                    nxt_weights[idx] = 5'd31;
                end else if(idx==7)begin
                    nxt_weights[idx] = char_weights[6] + char_weights[7];
                end else begin
                    nxt_weights[idx] = char_weights[idx];
                end
            end else begin
                nxt_weights[idx] = char_weights[idx];
            end
        end
    end
endgenerate


always @(posedge clk or negedge rst_n) begin : char_weight_and_output_mode_ctrl
    if(!rst_n)begin
        output_mode <= 0;
        for(i=0;i<8;i=i+1)begin
            char_weights[i] <= 0;
        end
    end else if(state == WAIT_INPUT) begin // load input values into char_weights and output_mode
        output_mode <= (in_valid && main_cnt==0) ? out_mode : output_mode;
        if(in_valid)begin
            char_weights[7] <= in_weight;
            for(i=0;i<7;i=i+1)begin
                char_weights[i] <= char_weights[i+1];
            end
        end
    end else if(state == MERGE)begin // update cahr_weights when merging
        for(i=0;i<7;i=i+1)begin
                char_weights[i] <= nxt_weights[i];
        end
    end
end

SORT_IP #(.IP_WIDTH(8)) sorter(
    .IN_character({nodes[0], nodes[1], nodes[2], nodes[3], nodes[4], nodes[5], nodes[6], nodes[7]}),
    .OUT_character(raw_sort_out),
    .IN_weight({char_weights[0], char_weights[1], char_weights[2], char_weights[3], char_weights[4], char_weights[5], char_weights[6], char_weights[7]})
);

// place pipeline regs at the sorter outputs
generate
    for(idx=0;idx<8;idx=idx+1)begin
        always @(posedge clk or negedge rst_n) begin : unpack_and_pipeline_sorter_outputs
            if(!rst_n)begin
                sorted_char[idx] <= 0;
            end else begin
                sorted_char[idx] <= raw_sort_out[4*idx+3:4*idx];
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
            // once a subtree root is merged, we have to increment the code_len of all leaf nodes under this subtree
            for(i=0;i<8;i=i+1)begin // i: orig char idx, A, B ... V
                if(root_idx[i] == sorted_char[6] || root_idx[i] == sorted_char[7])begin
                    code_len[i] <= code_len[i] + 1;
                end
            end
        end else if(state == OUTPUT)begin
            // decrement itself to indicate sendng one bit
            code_len[out_char_idx] <= (code_len[out_char_idx]==0) ? 0 : code_len[out_char_idx]-1;
        end else if(state == WAIT_INPUT)begin
            // clear all code_len
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
            if(root_idx[i] == sorted_char[6])begin // bigger, insert 0
                huff_code[i][code_len[i]] <= 0;
            end else if(root_idx[i] == sorted_char[7])begin // smaller, insert 1
                huff_code[i][code_len[i]] <= 1;
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin : nodes_ctrl
    if(!rst_n)begin
        nodes[A] <= A;
        nodes[B] <= B;
        nodes[C] <= C;
        nodes[E] <= E;
        nodes[I] <= I;
        nodes[L] <= L;
        nodes[O] <= O;
        nodes[V] <= V;
    end else if(state == WAIT_INPUT) begin
        nodes[A] <= A;
        nodes[B] <= B;
        nodes[C] <= C;
        nodes[E] <= E;
        nodes[I] <= I;
        nodes[L] <= L;
        nodes[O] <= O;
        nodes[V] <= V;
    end else if(state == MERGE) begin
        // discard nodes[6] cuz it will be merged with nodes[7]
        nodes[6] <= 4'b1111;
    end
end

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
            if(root_idx[i] == sorted_char[6] || root_idx[i] == sorted_char[7])begin
                root_idx[i] <= root_idx[7];
            end
        end
    end
end

assign out_valid = (state == OUTPUT);
always @(posedge clk or negedge rst_n) begin : output_ctrl
    if(!rst_n)begin
        out_code <= 0;
        // out_valid <= 0;
    end else begin
        if(state == OUTPUT)begin
            out_code <= huff_code[out_char_idx][code_len[out_char_idx]-1];
            
        end else begin
            out_code <= 0;
            // out_valid <= 0;
        end

    end
end


endmodule