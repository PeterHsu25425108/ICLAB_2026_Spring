`ifdef RTL
    `define CYCLE_TIME 6.7
`endif
`ifdef GATE
    `define CYCLE_TIME 6.7
`endif

module PATTERN(
    output reg      clk,
    output reg      rst_n,
    // AXI4-Lite Master
    input [31:0]    aw_addr,
    input           aw_valid,
    input           aw_ready,
    input [63:0]    w_data,
    input           w_valid,
    input           w_ready,
    input [1:0]     b_resp,
    input           b_valid,
    input           b_ready,
    
    input [31:0]    ar_addr,
    input           ar_valid,
    input           ar_ready,
    input [63:0]    r_data,
    input [1:0]     r_resp,
    input           r_valid,
    input           r_ready,

    output reg       in_mode_valid,
    output reg [1:0] in_mode,
    output reg       in_valid,
    output reg [1:0] in_bank,
    output reg [5:0] in_src_row,
    output reg [5:0] in_dst_row,
    output reg [63:0]in_data,
    
    input             out_valid,
    input [63:0]      out_data
);


// Golden Memory for Verification
reg [63:0] golden_DRAM [0:65535];
parameter DRAM_p_r = "../00_TESTBED/DRAM_init.dat";
initial $readmemh(DRAM_p_r, golden_DRAM);
//you can access psuedo_DRAM memory by u_DRAM.DRAM
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer total_latency;
integer latency;
real CYCLE = `CYCLE_TIME;

integer pat_num = 300; // Define how many test cases to run
integer i_pat;
integer i;

// ---------------------------------------------------------------------
//   AXI-Lite Protocol Tracking Variables
// ---------------------------------------------------------------------

integer aw_wait_ready_cnt, w_wait_ready_cnt, b_wait_ready_cnt;
integer ar_wait_ready_cnt, r_wait_ready_cnt;

integer aw_to_w_cnt, w_to_b_cnt, ar_to_r_cnt;

// FIFOs for SPEC AXI-6 (Response Timeout)
integer cycle_cnt;
integer aw_issue_t[0:1023], aw_head, aw_tail;
integer w_issue_t[0:10235],  w_head,  w_tail;
integer ar_issue_t[0:1023], ar_head, ar_tail;

// Outstanding counters for SPEC AXI-3 & AXI-6
integer aw_outstanding, w_outstanding, ar_outstanding;

// Registers to hold past values for SPEC AXI-2 (Stability Check)
reg past_aw_valid, past_aw_ready; reg [31:0] past_aw_addr;
reg past_w_valid,  past_w_ready;  reg [63:0] past_w_data;
reg past_b_valid,  past_b_ready;  reg [1:0]  past_b_resp;
reg past_ar_valid, past_ar_ready; reg [31:0] past_ar_addr;
reg past_r_valid,  past_r_ready;  reg [63:0] past_r_data; reg [1:0] past_r_resp;

//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg test_start = 0;
reg [1:0] current_mode;

reg [1:0] read_in_bank;
reg [5:0] read_in_src_row;

reg [1:0]  write_in_bank;
reg [5:0]  write_in_dst_row;

reg [5:0]  calc_in_src_row;
reg signed [63:0] golden_calc_ans [0:3];

reg [5:0]  sort_in_src_row;
reg [5:0]  sort_in_dst_row;
reg [63:0] sort_buffer [0:1023];

reg [63:0] random_data;
//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------

initial 
begin
	clk = 0;
end
always #(CYCLE/2.0) clk = ~clk;

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------

initial begin

    reset_signal_task;
    #(CYCLE*3);
    for (i_pat = 0; i_pat < pat_num; i_pat = i_pat + 1) begin
        current_mode = $urandom_range(0, 3);
		//if(current_mode == 3)current_mode = 1;
        //current_mode = 2;
		$display("PATTERN NO.%4d | Mode: %d", i_pat, current_mode);
		
		input_task;
        wait_out_valid_task;
        case(current_mode)
            2'd0: check_read_task;
            2'd1: check_write_task;
            2'd2: check_calc_task;
            2'd3: check_sort_task;
        endcase

        $display("PASS PATTERN NO.%4d | Mode: %d", i_pat, current_mode);
    end
    YOU_PASS_task;
    $finish; // Stop here for now to test Reset


end


// =======================================
// helper
// =======================================
task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                    Error message from PATTERN.v                       *");
end endtask
task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end endtask

task reset_signal_task; begin

    rst_n = 1'b1;
    in_mode_valid = 1'b0;
    in_mode = 2'bx;
    in_valid = 1'b0;
    in_bank = 2'bx;
    in_src_row = 6'bx;
    in_dst_row = 6'bx;
    in_data = 64'bx;

    total_latency = 0;
    aw_wait_ready_cnt = 0; 
    w_wait_ready_cnt = 0; 
    b_wait_ready_cnt = 0;
    ar_wait_ready_cnt = 0; 
    r_wait_ready_cnt = 0;
    aw_to_w_cnt = 0; 
    w_to_b_cnt = 0; 
    ar_to_r_cnt = 0;
    aw_outstanding = 0; 
    w_outstanding = 0; 
    ar_outstanding = 0;

    cycle_cnt = 0;
    aw_head = 0; 
    aw_tail = 0;
    w_head  = 0; 
    w_tail  = 0;
    ar_head = 0; 
    ar_tail = 0;

    test_start = 0;

    force clk = 0;  // Force clock to 0 for a stable reset start
    #(CYCLE*3); rst_n = 1'b0;
    #200.0;
    if (out_valid !== 1'b0 || out_data !== 64'b0 || 
        aw_addr !== 32'b0 || aw_valid !== 1'b0 || aw_ready !== 1'b0 ||
        w_data !== 64'b0 || w_valid !== 1'b0 || w_ready !== 1'b0 ||
        b_resp !== 2'b0 || b_valid !== 1'b0 || b_ready !== 1'b0 ||
        ar_addr !== 32'b0 || ar_valid !== 1'b0 || ar_ready !== 1'b0 ||
        r_data !== 64'b0 || r_resp !== 2'b0 || r_valid !== 1'b0 || r_ready !== 1'b0 ) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-1 FAIL                            *");
        $display("*************************************************************************");
        #CYCLE;
        $finish;
    end
    rst_n = 1'b1;
    #(CYCLE);  
    release clk;
    test_start = 1;
end endtask

task input_task; begin
    @(negedge clk);
    in_mode_valid = 1'b1;
    in_mode = current_mode;
    
    @(negedge clk);
    in_mode_valid = 1'b0;
    in_mode = 2'bx;
    
    case(current_mode)
        2'd0: input_read_task;
        2'd1: input_write_task;
        2'd2: input_calc_task;
        2'd3: input_sort_task;
    endcase
end endtask

task input_read_task; begin
    
    in_valid = 1'b1;
    in_bank    = $urandom_range(0, 3);
    read_in_bank = in_bank;
    in_src_row = $urandom_range(32, 62);
    read_in_src_row = in_src_row; 
    @(negedge clk);
    
    //
    in_valid   = 1'b0; // falling edge of in_valid
    in_bank    = 2'bx;
    in_src_row = 6'bx;

end endtask

task wait_out_valid_task; begin
    latency = 0;
    while (out_valid !== 1'b1) begin
        if (latency > 10000) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-2 FAIL                            *");
            $display("*************************************************************************");
            $finish;
        end
        @(negedge clk);
        latency = latency + 1;
    end
    total_latency = total_latency + latency;
end endtask

task check_read_task; begin
    for ( i = 0; i < 256; i = i + 1) begin

        if (out_valid !== 1'b1) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-3 FAIL                            *");
            $display("*                           MODE :  read                                *");
            $display("*************************************************************************");
            $finish;
        end
        
        if (out_data !== golden_DRAM[{read_in_bank[1:0], read_in_src_row[5:0], i[7:0]}]) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-4 FAIL                            *");
            $display("*                           MODE :  read                                *");
            $display("* DATA mismatch at Col: %d. Expected: %h, Got: %h *", i, golden_DRAM[{read_in_bank[1:0], read_in_src_row[5:0], i[7:0]}], out_data);
            $display("*************************************************************************");
            $finish;
        end
        
        @(negedge clk);
    end
    
    // After 256 cycles, out_valid MUST drop back to 0
    if (out_valid === 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("*     After reading 256 cycles, out_valid MUST drop back to 0           *");
        $display("*************************************************************************");
        $finish;
    end
    
end endtask


task input_write_task; begin

    write_in_bank = $urandom_range(0, 3);
    write_in_dst_row = $urandom_range(32, 62); 

    in_valid   = 1'b1;
    in_bank    = write_in_bank;
    in_dst_row = write_in_dst_row;

    for (integer i = 0; i < 256; i = i + 1) begin

        random_data = {$urandom, $urandom};
        in_data = random_data;

        golden_DRAM[{in_bank[1:0], in_dst_row, i[7:0]}] = random_data;

        @(negedge clk);
    end

    in_valid   = 1'b0;
    in_bank    = 2'bx;
    in_dst_row = 6'bx;
    in_data    = 64'bx;

end endtask

task check_write_task; begin
    
    if (out_valid !== 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("*                           MODE :  write                               *");
        $display("*************************************************************************");
        $finish;
    end

    
    for (integer i = 0; i < 256; i = i + 1) begin
        
        if (u_DRAM.DRAM[{write_in_bank, write_in_dst_row, i[7:0]}] !== golden_DRAM[{write_in_bank, write_in_dst_row, i[7:0]}]) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-5 FAIL                            *");
            $display("*                           MODE :  write                               *");
            $display("* DRAM data mismatch at Col: %d. Expected: %h, Got: %h *", 
                      i, golden_DRAM[{write_in_bank, write_in_dst_row, i[7:0]}], 
                      u_DRAM.DRAM[{write_in_bank, write_in_dst_row, i[7:0]}]);
            $display("*************************************************************************");
            $finish;
        end
    end

    @(negedge clk); 

    if (out_valid === 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("*      After WRITE operation, out_valid MUST drop back to 0             *");
        $display("*************************************************************************");
        $finish;
    end

end endtask

task input_calc_task; begin
    
    calc_in_src_row = $urandom_range(0, 31);

    in_valid   = 1'b1;
    in_src_row = calc_in_src_row;
    
    @(negedge clk);
    
    in_valid   = 1'b0;
    in_src_row = 6'bx;

end endtask


task check_calc_task; begin
    calc_golden_task();

    for (integer i = 0; i < 4; i = i + 1) begin
        if (out_valid !== 1'b1) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-3 FAIL                            *");
            $display("* CALC mode out_valid must be high for 4 cycles.                        *");
            $display("*************************************************************************");
            $finish;
        end

        // Check the sequential output: Bank 0 -> Bank 1 -> Bank 2 -> Bank 3
        if (out_data !== golden_calc_ans[i]) begin
            $display("*************************************************************************");
            $display("*                           SPEC MAIN-4 FAIL                            *");
            $display("*                           MODE :  calc                                *");
            $display("* CALC mismatch at Bank %d. Expected: %h, Got: %h *", i, golden_calc_ans[i], out_data);
            $display("*************************************************************************");
            $finish;
        end
        
        @(negedge clk);
    end

    // After 4 cycles, out_valid MUST drop back to 0
    if (out_valid === 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("*     After 4 cycles in CALC mode, out_valid MUST drop back to 0        *");
        $display("*************************************************************************");
        $finish;
    end
end endtask


task calc_golden_task; begin
    golden_calc_ans[0] = evaluate_tree({2'd0, calc_in_src_row, 8'd0});
    golden_calc_ans[1] = evaluate_tree({2'd1, calc_in_src_row, 8'd0});
    golden_calc_ans[2] = evaluate_tree({2'd2, calc_in_src_row, 8'd0});
    golden_calc_ans[3] = evaluate_tree({2'd3, calc_in_src_row, 8'd0});
end endtask


task input_sort_task; begin
    
    sort_in_src_row = $urandom_range(0, 62);
    sort_in_dst_row = $urandom_range(32, 62);

    in_valid   = 1'b1;
    in_src_row = sort_in_src_row;
    in_dst_row = sort_in_dst_row;
    
    @(negedge clk);
    
    
    in_valid   = 1'b0;
    in_src_row = 6'bx;
    in_dst_row = 6'bx;

end endtask

task sort_golden_task; 

    integer i, j, b, c;
    reg [63:0] temp_data;
    reg signed [30:0] val1;
    reg signed [30:0] val2;

    begin
    
    for (b = 0; b < 4; b = b + 1) begin
        for (c = 0; c < 256; c = c + 1) begin
            sort_buffer[b*256 + c] = golden_DRAM[{b[1:0], sort_in_src_row, c[7:0]}];
        end
    end
    
    for (i = 0; i < 1024; i = i + 1) begin
        for (j = 0; j < 1023 - i; j = j + 1) begin
            if (sort_buffer[j][62:32] > sort_buffer[j+1][62:32]) begin
                // Swap the entire 64-bit data
                temp_data        = sort_buffer[j];
                sort_buffer[j]   = sort_buffer[j+1];
                sort_buffer[j+1] = temp_data;
            end
        end
    end
    
    for (b = 0; b < 4; b = b + 1) begin
        for (c = 0; c < 256; c = c + 1) begin
            golden_DRAM[{b[1:0], sort_in_dst_row, c[7:0]}] = sort_buffer[b*256 + c];
        end
    end
end endtask

task check_sort_task; begin
    
    sort_golden_task();

    if (out_valid !== 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("* SORT mode out_valid must be high for 1 cycle.                         *");
        $display("*************************************************************************");
        $finish;
    end

    for (integer b = 0; b < 4; b = b + 1) begin
        for (integer c = 0; c < 256; c = c + 1) begin
            if (u_DRAM.DRAM[{b[1:0], sort_in_dst_row, c[7:0]}] !== golden_DRAM[{b[1:0], sort_in_dst_row, c[7:0]}]) begin
                $display("*************************************************************************");
                $display("*                           SPEC MAIN-5 FAIL                            *");
                $display("*                           MODE :  sort                                *");
                $display("* SORT mismatch at Bank %d, Col %d. Expected: %h, Got: %h *", 
                          b, c, golden_DRAM[{b[1:0], sort_in_dst_row, c[7:0]}], 
                          u_DRAM.DRAM[{b[1:0], sort_in_dst_row, c[7:0]}]);
                $display("*************************************************************************");
                $finish;
            end
        end
    end
    
    @(negedge clk);
    
    // After 1 cycle, out_valid MUST drop back to 0
    if (out_valid === 1'b1) begin
        $display("*************************************************************************");
        $display("*                           SPEC MAIN-3 FAIL                            *");
        $display("* After SORT operation, out_valid MUST drop back to 0                   *");
        $display("*************************************************************************");
        $finish;
    end
end endtask

// function 

// Automatic function allows recursion in Verilog
function automatic signed [63:0] evaluate_tree;
    input [15:0] node_ptr; // {Bank[1:0], Row[5:0], Col[7:0]}
    
    reg [63:0] node_data;
    reg [1:0]  bank;
    reg [5:0]  row;
    reg [7:0]  col;
    reg        is_op;
    reg [1:0]  opcode;
    
    reg [15:0] left_ptr;
    reg [15:0] right_ptr;
    reg signed [63:0] left_val;
    reg signed [63:0] right_val;
    reg signed [63:0] int_val;
    begin

        bank = node_ptr[15:14];
        row  = node_ptr[13:8];
        col  = node_ptr[7:0];
        
        node_data = golden_DRAM[{bank, row, col}];
        
        is_op = node_data[63]; // Type bit: 0 = Number, 1 = Operator

        if (is_op == 1'b0) begin // Type 0: Number node.
            int_val = {{33{node_data[62]}}, node_data[62:32]}; // The 31-bit signed integer is at [62:32]. We must sign-extend it to 64 bits.
            evaluate_tree = int_val;
        end 
        else begin // Type 1: Operator node.
            
            opcode    = node_data[33:32];
            left_ptr  = node_data[31:16];
            right_ptr = node_data[15:0];
            
            // Recursive calls for left and right children
            left_val  = evaluate_tree(left_ptr);
            right_val = evaluate_tree(right_ptr);
            
            // Perform 64-bit signed arithmetic based on opcode
            case (opcode)
                2'b00: evaluate_tree = left_val + right_val;
                2'b01: evaluate_tree = left_val - right_val;
                2'b10: evaluate_tree = left_val * right_val;
                2'b11: evaluate_tree = left_val >>> right_val[5:0]; // Arithmetic Shift Right
                default: evaluate_tree = 64'd0;
            endcase
        end
    end
endfunction

always @(posedge clk) begin
    past_aw_valid <= aw_valid; past_aw_ready <= aw_ready; past_aw_addr <= aw_addr;
    past_w_valid  <= w_valid;  past_w_ready  <= w_ready;  past_w_data  <= w_data;
    past_b_valid  <= b_valid;  past_b_ready  <= b_ready;  past_b_resp  <= b_resp;
    past_ar_valid <= ar_valid; past_ar_ready <= ar_ready; past_ar_addr <= ar_addr;
    past_r_valid  <= r_valid;  past_r_ready  <= r_ready;  past_r_data  <= r_data; past_r_resp <= r_resp;
end

always @(negedge clk) begin
    if (rst_n && test_start) begin
        cycle_cnt = cycle_cnt + 1;

        if (aw_valid && !aw_ready) aw_wait_ready_cnt = aw_wait_ready_cnt + 1; else aw_wait_ready_cnt = 0;
        if (w_valid && !w_ready) w_wait_ready_cnt = w_wait_ready_cnt + 1; else w_wait_ready_cnt = 0;
        if (b_valid && !b_ready) b_wait_ready_cnt = b_wait_ready_cnt + 1; else b_wait_ready_cnt = 0;
        if (ar_valid && !ar_ready) ar_wait_ready_cnt = ar_wait_ready_cnt + 1; else ar_wait_ready_cnt = 0;
        if (r_valid && !r_ready) r_wait_ready_cnt = r_wait_ready_cnt + 1; else r_wait_ready_cnt = 0;

        
        if (aw_valid && aw_ready) begin aw_issue_t[aw_head] = cycle_cnt; aw_head = (aw_head + 1) % 1024; end
        if (w_valid && w_ready)   begin aw_tail = (aw_tail + 1) % 1024; end
        
        if (w_valid && w_ready)   begin w_issue_t[w_head] = cycle_cnt; w_head = (w_head + 1) % 1024; end
        if (b_valid && b_ready)   begin w_tail = (w_tail + 1) % 1024; end
        
        if (ar_valid && ar_ready) begin ar_issue_t[ar_head] = cycle_cnt; ar_head = (ar_head + 1) % 1024; end
        if (r_valid && r_ready)   begin ar_tail = (ar_tail + 1) % 1024; end


        
        if (!aw_valid && aw_addr !== 32'd0) begin
            $display("=================================================");
            $display("[SPEC AXI-1 ERROR] aw_addr is not 0 when aw_valid is low!");
            $display("Current aw_addr = %h", aw_addr);
            $display("=================================================");
            display_axi_1_fail;
        end
        
        if (!w_valid  && w_data  !== 64'd0) begin
            $display("=================================================");
            $display("[SPEC AXI-1 ERROR] w_data is not 0 when w_valid is low!");
            $display("Current w_data = %h", w_data);
            $display("=================================================");
            display_axi_1_fail;
        end
        
        if (!b_valid  && b_resp  !== 2'd0) begin
            $display("=================================================");
            $display("[SPEC AXI-1 ERROR] b_resp is not 0 when b_valid is low!");
            $display("Current b_resp = %h", b_resp);
            $display("=================================================");
            display_axi_1_fail;
        end
        
        if (!ar_valid && ar_addr !== 32'd0) begin
            $display("=================================================");
            $display("[SPEC AXI-1 ERROR] ar_addr is not 0 when ar_valid is low!");
            $display("Current ar_addr = %h", ar_addr);
            $display("=================================================");
            display_axi_1_fail;
        end
        
        if (!r_valid  && (r_data !== 64'd0 || r_resp !== 2'd0)) begin
            $display("=================================================");
            $display("[SPEC AXI-1 ERROR] r_data or r_resp is not 0 when r_valid is low!");
            $display("Current r_data = %h, r_resp = %h", r_data, r_resp);
            $display("=================================================");
            display_axi_1_fail;
        end

        
        if (past_aw_valid && !past_aw_ready && (!aw_valid || aw_addr !== past_aw_addr)) display_axi_2_fail;
        if (past_w_valid  && !past_w_ready  && (!w_valid  || w_data  !== past_w_data))  display_axi_2_fail;
        if (past_b_valid  && !past_b_ready  && (!b_valid  || b_resp  !== past_b_resp))  display_axi_2_fail;
        if (past_ar_valid && !past_ar_ready && (!ar_valid || ar_addr !== past_ar_addr)) display_axi_2_fail;
        if (past_r_valid  && !past_r_ready  && (!r_valid  || r_data  !== past_r_data || r_resp !== past_r_resp)) display_axi_2_fail;

        
        if (w_valid && !aw_valid && aw_outstanding == 0) display_axi_3_fail;

        
        if (aw_valid && (aw_addr > 32'd65535)) display_axi_4_fail;
        if (ar_valid && (ar_addr > 32'd65535)) display_axi_4_fail;

        
        if (aw_wait_ready_cnt > 50) display_axi_5_fail;
        if (w_wait_ready_cnt > 100) display_axi_5_fail;
        if (b_wait_ready_cnt > 100) display_axi_5_fail;
        if (ar_wait_ready_cnt > 50) display_axi_5_fail;
        if (r_wait_ready_cnt > 100) display_axi_5_fail;

        
        if (aw_head != aw_tail) begin
            if (!w_valid && (cycle_cnt - aw_issue_t[aw_tail] > 150)) begin
                $display("Timeout AW waiting for W channel");
                display_axi_6_fail;
            end
        end
        
        if (w_head != w_tail) begin
            if (!b_valid && (cycle_cnt - w_issue_t[w_tail] > 150)) begin
                $display("Timeout W waiting for B channel");
                display_axi_6_fail;
            end
        end

        if (ar_head != ar_tail) begin
            if (!r_valid && (cycle_cnt - ar_issue_t[ar_tail] > 150)) begin
                $display("Timeout AR waiting for R channel");
                display_axi_6_fail;
            end
        end

        
        if (aw_valid && aw_ready) aw_outstanding = aw_outstanding + 1;
        if (w_valid && w_ready)   aw_outstanding = aw_outstanding - 1;
        
        if (ar_valid && ar_ready) ar_outstanding = ar_outstanding + 1;
        if (r_valid && r_ready)   ar_outstanding = ar_outstanding - 1;
    end
end

task display_axi_1_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-1 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask

task display_axi_2_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-2 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask

task display_axi_3_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-3 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask

task display_axi_4_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-4 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask

task display_axi_5_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-5 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask

task display_axi_6_fail; begin
    $display("*************************************************************************");
    $display("*                          SPEC AXI-6 FAIL                              *");
    $display("*************************************************************************");
    $finish;
end endtask


endmodule










// $display("*************************************************************************");
// $display("*                           SPEC MAIN-1 FAIL                            *");
// $display("*                           SPEC MAIN-2 FAIL                            *");
// $display("*                           SPEC MAIN-3 FAIL                            *");
// $display("*                           SPEC MAIN-4 FAIL                            *");
// $display("*                           SPEC MAIN-5 FAIL                            *");
// $display("*************************************************************************");

// $display("*************************************************************************");
// $display("*                          SPEC AXI-1 FAIL                              *");
// $display("*                          SPEC AXI-2 FAIL                              *");
// $display("*                          SPEC AXI-3 FAIL                              *");
// $display("*                          SPEC AXI-4 FAIL                              *");
// $display("*                          SPEC AXI-5 FAIL                              *");
// $display("*                          SPEC AXI-6 FAIL                              *");
// $display("*************************************************************************");