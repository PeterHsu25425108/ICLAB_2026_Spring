`define CYCLE_TIME 20.0

module PATTERN #(parameter IP_WIDTH)( 
    output reg [IP_WIDTH*4-1:0] IN_character,
    output reg [IP_WIDTH*5-1:0] IN_weight,
    input      [IP_WIDTH*4-1:0] OUT_character
);

// ========================================
// Parameter & Variables
// ========================================
integer PATNUM = 10; 
integer i_pat, i, j;

reg [IP_WIDTH*4-1:0] golden_out;

reg [4:0] weight_arr [0:IP_WIDTH-1];
reg [3:0] char_arr   [0:IP_WIDTH-1];

reg [8:0] combined_arr [0:IP_WIDTH-1];
reg [8:0] temp_swap;

//================================================================
// clock
//================================================================
reg clk;
real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;
initial clk = 0;

//================================================================
// initial & Main Block
//================================================================
initial begin
	$display("========================================================");
    $display("   [INFO] Start Simulation with IP_WIDTH = %0d", IP_WIDTH);
    $display("========================================================");
	
    IN_character = 0;
    IN_weight    = 0;
    repeat(2) @(negedge clk);

    if(OUT_character !== 0) begin
        $display("********************************************************");      
        $display("* FAIL!                                                *");
        $display("* Input should not be zero.                            *"); 
        $display("********************************************************");
        repeat(2) @(negedge clk);
        $finish;
    end

    // ========================================
    // Verification Loop
    // ========================================
    for(i_pat = 0; i_pat < PATNUM; i_pat = i_pat + 1) begin
        
        generate_random_inputs();
        
        calculate_golden();

        update_inputs();
        
        @(negedge clk);

        if(OUT_character !== golden_out) begin
            $display("********************************************************");      
            $display("* FAIL at Pattern No.%4d                             *", i_pat);
            $display("* Your output  : %h", OUT_character); 
            $display("* Golden ouput : %h", golden_out); 
            $display("********************************************************");
            
            $display("Input Weights : ");
            for(i=0; i<IP_WIDTH; i=i+1) $write("%2d ", weight_arr[i]);
            $display("\nInput Chars   : ");
            for(i=0; i<IP_WIDTH; i=i+1) $write(" %h ", char_arr[i]);
            $display("\n");
            
            repeat(2) @(negedge clk);
            $finish;
        end

 
        $display("\033[0;34mPASS PATTERN NO.%4d \033[m", i_pat);
    end
    
    $display("\033[0;32mAll %0d Patterns PASSED! \033[m", PATNUM);
    repeat(5) @(negedge clk);
    display_pass();
    $finish; 
end


task generate_random_inputs;
    begin
        for(i = 0; i < IP_WIDTH; i = i + 1) begin
            char_arr[i]   = i; 
            weight_arr[i] = $urandom_range(0, 31); 
        end
    end
endtask


task calculate_golden;
    begin
        for(i = 0; i < IP_WIDTH; i = i + 1) begin
            combined_arr[i] = {weight_arr[i], char_arr[i]};
        end

        for(i = 0; i < IP_WIDTH - 1; i = i + 1) begin
            for(j = 0; j < IP_WIDTH - 1 - i; j = j + 1) begin
                if(combined_arr[j] < combined_arr[j+1]) begin
                    temp_swap         = combined_arr[j];
                    combined_arr[j]   = combined_arr[j+1];
                    combined_arr[j+1] = temp_swap;
                end
            end
        end

        golden_out = 0;
        for(i = 0; i < IP_WIDTH; i = i + 1) begin
            golden_out[((IP_WIDTH-i)*4)-1 -: 4] = combined_arr[i][3:0];
        end
    end
endtask


task update_inputs;
    begin
        for(i = 0; i < IP_WIDTH; i = i + 1) begin
            IN_character[(i*4)+3 -: 4] = char_arr[i];
            IN_weight[(i*5)+4 -: 5]    = weight_arr[i];
        end
    end
endtask


task display_pass;
begin
        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\\__||  ");
        $display("        --  Congratulations !!    --      / O.O  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  Simulation out!!     --    /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("\n");
end
endtask

endmodule