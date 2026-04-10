//###############################################################################################
//    File Name   : SORT_IP.v
//    Module Name : SORT_IP
//    Description : Parallel Rank Sort (Stable Sort, MSB Priority)
//###############################################################################################

module SORT_IP #(parameter IP_WIDTH = 8)(
    input  [IP_WIDTH*4-1:0] IN_character,
    input  [IP_WIDTH*5-1:0] IN_weight,
    output [IP_WIDTH*4-1:0] OUT_character
);

// ======================================================
// Wire & Reg Declaration
// ======================================================
wire [4:0] weight  [0:IP_WIDTH-1];
wire [3:0] char_in [0:IP_WIDTH-1];
wire       win     [0:IP_WIDTH-1][0:IP_WIDTH-1];
reg  [2:0] rank    [0:IP_WIDTH-1];
reg  [3:0] sorted_char [0:IP_WIDTH-1];

integer x, y, k, m;
genvar i, j;

// ======================================================
// Design Start
// ======================================================

// 1. Unpack inputs: Index 0 maps to MSB, Index IP_WIDTH-1 maps to LSB
generate
    for (i = 0; i < IP_WIDTH; i = i + 1) begin : UNPACK
        assign weight[i]  = IN_weight[5*(IP_WIDTH-1-i)+4 : 5*(IP_WIDTH-1-i)];
        assign char_in[i] = IN_character[4*(IP_WIDTH-1-i)+3 : 4*(IP_WIDTH-1-i)];
    end
endgenerate

// 2. Stage 1: Comparators (Win/Loss matrix)
generate
    for (i = 0; i < IP_WIDTH; i = i + 1) begin : CMP_ROW
        for (j = 0; j < IP_WIDTH; j = j + 1) begin : CMP_COL
            if (i == j) begin
                assign win[i][j] = 1'b0; // Cannot beat itself
            end else if (i < j) begin
                // Element i is closer to MSB than element j
                // Standard Stable Sort: MSB-side wins tie-breaker
                assign win[i][j] = (weight[i] >= weight[j]);
            end else begin
                // Element i is closer to LSB than element j
                // Must be strictly greater to win
                assign win[i][j] = (weight[i] > weight[j]);
            end
        end
    end
endgenerate

// 3. Stage 2: Rank calculation (Adder Tree)
// Calculate how many elements the current element beats
always @(*) begin
    for (x = 0; x < IP_WIDTH; x = x + 1) begin
        rank[x] = 3'd0;
        for (y = 0; y < IP_WIDTH; y = y + 1) begin
            rank[x] = rank[x] + win[x][y];
        end
    end
end

// 4. Stage 3: Output Routing (Crossbar MUX)
// Assign characters to their sorted positions based on rank
always @(*) begin
    for (k = 0; k < IP_WIDTH; k = k + 1) begin
        sorted_char[k] = 4'd0; // Default value
        for (m = 0; m < IP_WIDTH; m = m + 1) begin
            // Highest rank (IP_WIDTH-1) goes to k=0 (MSB side of output)
            if (rank[m] == (IP_WIDTH - 1 - k)) begin
                sorted_char[k] = char_in[m];
            end
        end
    end
end

// 5. Pack outputs: Index 0 maps to MSB, Index IP_WIDTH-1 maps to LSB
generate
    for (i = 0; i < IP_WIDTH; i = i + 1) begin : PACK_OUT
        assign OUT_character[4*(IP_WIDTH-1-i)+3 : 4*(IP_WIDTH-1-i)] = sorted_char[i];
    end
endgenerate

endmodule