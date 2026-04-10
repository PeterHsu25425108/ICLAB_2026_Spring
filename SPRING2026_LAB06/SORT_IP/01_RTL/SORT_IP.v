//###############################################################################################
//***********************************************************************************************
//    File Name   : SORT_IP.v
//    Module Name : SORT_TP
//***********************************************************************************************
//###############################################################################################

module SORT_IP #(parameter IP_WIDTH = 8)(
    //Input signals
    IN_character, IN_weight,
    //Output signals
    OUT_character
);

// ======================================================
// Input & Output Declaration
// ======================================================
input  [IP_WIDTH*4-1:0] IN_character;
input  [IP_WIDTH*5-1:0] IN_weight;

output [IP_WIDTH*4-1:0] OUT_character;

// ======================================================
// Wire & Reg Declaration
// ======================================================
wire [3:0] char_id [0:IP_WIDTH-1];
wire [4:0] char_w  [0:IP_WIDTH-1];
wire [8:0] char_w_id [0:IP_WIDTH-1]; 

wire [8:0] stage_data [0:IP_WIDTH-1][0:IP_WIDTH-1]; 
wire [8:0] insert_target [0:IP_WIDTH-1];

// ======================================================
// Design start
// ======================================================

genvar i, j;
generate
    // Unpack inputs, concatenate for comparison, and assign outputs
    for(i=0; i<IP_WIDTH; i=i+1) begin: unpack_inputs_and_outputs
        assign char_id[i]   = IN_character[4*i+3:4*i];
        assign char_w[i]    = IN_weight[5*i+4:5*i];
        
        // Combine weight and id. Weight is MSB so it is compared first.
        assign char_w_id[i] = {char_w[i], char_id[i]};
        
        // Only output the 4-bit character from the final stage
        assign OUT_character[4*i+3:4*i] = stage_data[IP_WIDTH-1][/*IP_WIDTH-1-*/i][3:0];
    end
endgenerate

// Initialize the first stage with the initial array
generate
	for (i = 0; i < IP_WIDTH; i = i + 1) begin
		assign stage_data[0][i] = char_w_id[i];
	end
endgenerate

generate
    for (i = 1; i < IP_WIDTH; i = i + 1) begin : STAGE
        
        // Grab the current element to insert directly from the prepared array
        assign insert_target[i] = char_w_id[i];

        for (j = 0; j < IP_WIDTH; j = j + 1) begin : MUX_LOGIC
            if (j == 0) begin
                // Head position: compare full 9 bits using >
                assign stage_data[i][j] = (insert_target[i][8:4] < stage_data[i-1][0][8:4]) ? insert_target[i] : stage_data[i-1][0];
            end 
            else if (j == i) begin
                // Tail position
                assign stage_data[i][j] = (insert_target[i][8:4] < stage_data[i-1][j-1][8:4]) ? stage_data[i-1][j-1] : insert_target[i];
            end 
            else if(j > 0 && j < i) begin
                // Middle positions
                assign stage_data[i][j] = (insert_target[i][8:4] < stage_data[i-1][j-1][8:4]) ? stage_data[i-1][j-1] : 
                                          ((insert_target[i][8:4] < stage_data[i-1][j][8:4])  ? insert_target[i]     : stage_data[i-1][j]);
            end else begin
                // Pass through
                assign stage_data[i][j] = stage_data[i-1][j];
            end
        end
    end
endgenerate

endmodule