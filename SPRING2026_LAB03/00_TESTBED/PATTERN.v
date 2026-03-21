`define DEBUG 0
`define EDGE_CASE 1
`define PAT_CYCLE_TIME 40.0


`ifdef RTL
    `define CYCLE_TIME `PAT_CYCLE_TIME
`endif
`ifdef GATE
    `define CYCLE_TIME `PAT_CYCLE_TIME
`endif

module PATTERN(
    output reg      clk,
    output reg      rst_n,

    // Watch AXI4-Lite signals
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

    // PATTERN -> Harvester
    // valid signals
    output reg       in_mode_valid,
    output reg       in_valid,
    // output data signals
    output reg [1:0] in_mode,
    output reg [1:0] in_bank,
    output reg [5:0] in_src_row,
    output reg [5:0] in_dst_row,
    output reg [63:0]in_data,
    
    // Harvestor -> PATTERN
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
integer total_latency = 0;
real CYCLE = `CYCLE_TIME;

parameter PATNUM = 1000;
integer patcount;
integer latency = 0;
integer i;
integer k,j;
integer DEBUG = `DEBUG;
integer EDGE_CASE = `EDGE_CASE;

integer expected_cycles;
integer valid_count;
integer col_idx;
// these are the pre-generated testcases which will later be assigbed to the outputs
reg[1:0] mode_rand;
reg [5:0] src_row_rand;
reg [1:0] bank_rand;
reg [5:0] dst_row_rand;
integer wait_gap;
reg [63:0] in_data_rand [0:255]; // 用於 WRITE 模式的 256 筆資料
reg [63:0] calc_mode_golden [0:3]; // the golden outputs of the CALC mode
reg [15:0] dram_idx; // index for dram access
reg [63:0] out_cycle_data [0:255]; // 用於暫存輸出的資料方便在 check_ans_task 中比對，不一定填滿
reg [63:0] expected_data; // 用於暫存預期資料的變數
reg [63:0] dbg_golden;
reg [63:0] dbg_udram;

// Debug registers for SORT mode failures (easily visible in waveform)
reg [63:0] sort_fail_actual_data;   // Actual DRAM data that caused mismatch
reg [63:0] sort_fail_expected_data; // Expected golden data
reg [63:0] sort_fail_actual_data_LAST;   // Actual DRAM data of the previous column (for context)
reg [63:0] sort_fail_expected_data_LAST; // Expected golden data of the previous column (for context)
reg [15:0] sort_fail_address;       // Full address {bank, row, col}
reg [2:0]  sort_fail_bank_idx;      // Bank index of failure
reg [5:0]  sort_fail_row_idx;       // Row index of failure
reg [7:0]  sort_fail_col_idx;       // Column index of failure

reg sys_rst = 0; // indicate if the sys has been reset
// READ: check out_data == 指定的 in_bank 與 in_src_row (範圍 0~62) 內 Column 0~255 的 Golden 資料

// refer to golden_DRAM for READ mode
// DRAM addrees format: {bank[1:0], row[5:0], col[7:0]} = 16 bits total, so each row has 256 columns (64-bit each), and there are 4 banks and 64 rows per bank.
// access DRAM data from u_DRAM.DRAM
			
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg err_main1, err_main2, err_main3, err_main4, err_main5;
reg err_axi1, err_axi2, err_axi3, err_axi4, err_axi5, err_axi6;

always @(*) begin
    dbg_golden = golden_DRAM[{2'd3, 6'd50, 8'd255}];
    dbg_udram  = u_DRAM.DRAM[{2'd3, 6'd50, 8'd255}];
end

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
always	#(CYCLE/2.0) clk = ~clk;

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------
initial begin
    clk = 0;
    err_main1 = 0; err_main2 = 0; err_main3 = 0; err_main4 = 0; err_main5 = 0;
    err_axi1 = 0;  err_axi2 = 0;  err_axi3 = 0;  err_axi4 = 0;  err_axi5 = 0;  err_axi6 = 0;

    // Fix random seed for reproducible error reproduction (SPEC_MAIN4_FAIL debugging)
    // $srandom(12345);

    // Reset the system and check reset behavior(SPEC MAIN-1)
    reset_task;
    for(patcount=0;patcount<PATNUM;patcount=patcount+1) begin
        run_pat_task;
        // display pass message for each pattern
        $display("PASS PATTERN NO.%4d!", patcount+1);
    end

    // if      (err_main1) SPEC_MAIN1_FAIL;
    // else if (err_axi1)  SPEC_AXI1_FAIL;
    // else if (err_axi2)  SPEC_AXI2_FAIL;
    // else if (err_axi3)  SPEC_AXI3_FAIL;
    // else if (err_axi4)  SPEC_AXI4_FAIL;
    // else if (err_axi5)  SPEC_AXI5_FAIL;
    // else if (err_axi6)  SPEC_AXI6_FAIL;
    // else if (err_main2) SPEC_MAIN2_FAIL;
    // else if (err_main3) SPEC_MAIN3_FAIL;
    // else if (err_main4) SPEC_MAIN4_FAIL;
    // else if (err_main5) SPEC_MAIN5_FAIL;

    YOU_PASS_task;
end
// =======================================
// helper
// =======================================
// task YOU_FAIL_task; begin
//     $display("*                              FAIL!                                    *");
//     $display("*                    Error message from PATTERN.v                       *");
// end endtask

// =======================================
//  Master Checker (Combinational Logic)
// =======================================
// 優先權順序：MAIN-1 > AXI-1 > AXI-2 > AXI-3 > AXI-4 > AXI-5 > AXI-6 > MAIN-2 > MAIN-3 > MAIN-4 > MAIN-5
always @(*) begin
    if      (err_main1) SPEC_MAIN1_FAIL;
    else if (err_axi1)  SPEC_AXI1_FAIL;
    else if (err_axi2)  SPEC_AXI2_FAIL;
    else if (err_axi3)  SPEC_AXI3_FAIL;
    else if (err_axi4)  SPEC_AXI4_FAIL;
    else if (err_axi5)  SPEC_AXI5_FAIL;
    else if (err_axi6)  SPEC_AXI6_FAIL;
    else if (err_main2) SPEC_MAIN2_FAIL;
    else if (err_main3) SPEC_MAIN3_FAIL;
    else if (err_main4) SPEC_MAIN4_FAIL;
    else if (err_main5) SPEC_MAIN5_FAIL;
end

task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end endtask

task check_output_task; begin
    latency = 0;
    // =======================================================
    // 階段一：等待 out_valid 拉高 (同時檢查 MAIN-2 Latency)
    // =======================================================
    while (out_valid === 1'b0) begin
        latency = latency + 1;
        // $display("Waiting for out_valid to go high... Current latency: %d cycles", latency);
        if (latency > 10000) begin
            err_main2 = 1'b1; // 超過 10000 cycles，觸發 MAIN-2 錯誤
            $display("Latency exceeded 10000 cycles while waiting for out_valid to go high.");
            // SPEC_MAIN2_FAIL;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;

    // =======================================================
    // 階段二：out_valid 已經拉高，計算維持的週期 (MAIN-3) 與檢查資料 (MAIN-4)
    // =======================================================
    // 根據當前模式設定預期週期數
    
    if      (mode_rand === 2'd0) expected_cycles = 256; // READ
    else if (mode_rand === 2'd1) expected_cycles = 1;   // WRITE
    else if (mode_rand === 2'd2) expected_cycles = 4;   // CALC
    else if (mode_rand === 2'd3) expected_cycles = 1;   // SORT

    valid_count = 0;
    
    // 當 out_valid 保持為 1 時，持續迴圈
    // and store the output of each cycle into out_cycle_data
    while (out_valid === 1'b1) begin
        valid_count = valid_count + 1;

        out_cycle_data[valid_count - 1] = out_data; // 將每個週期的輸出資料存入陣列
        
        // 檢查 MAIN-3 (太長)：如果維持的週期數已經超過預期，直接報錯
        if (valid_count > expected_cycles) begin
            err_main3 = 1'b1; 
        end
        
        @(negedge clk);
    end

    // =======================================================
    // 階段三：out_valid 掉下來了，做最後確認
    // =======================================================
    // 檢查 MAIN-3 (太短)：如果掉下來時，週期數少於預期，報錯
    if (valid_count < expected_cycles) begin
        err_main3 = 1'b1;
    end

    // ===================================================
    // 檢查 MAIN-4：不論太長或太短，只要 out_valid 是 1，資料就必須正確
    // ===================================================
    check_ans_task;

end endtask

// 必須宣告為 automatic 才能支援遞迴
function automatic signed [63:0] eval_tree;
    input [15:0] node_addr; // 16-bit 絕對位址 {Bank, Row, Col}
    
    reg [63:0] node_data;
    reg signed [63:0] left_val;
    reg signed [63:0] right_val;
    begin
        // 從 Golden DRAM 中讀取該節點的資料
        node_data = golden_DRAM[node_addr];

        if (node_data[63] == 1'b0) begin
            // ----------------------------------------------------
            // 情況一：是 Number Node (葉節點)
            // ----------------------------------------------------
            // 取出 [62:32] 的 31-bit 數值，並做 Sign Extension 到 64 bits
            eval_tree = { {33{node_data[62]}}, node_data[62:32] };
            
        end else begin
            // ----------------------------------------------------
            // 情況二：是 Operator Node (父節點)
            // ----------------------------------------------------
            // 1. 遞迴計算左子樹與右子樹
            left_val  = eval_tree(node_data[31:16]);
            right_val = eval_tree(node_data[15:0]);
            
            // 2. 根據 Opcode 執行運算
            case (node_data[33:32])
                2'b00: eval_tree = left_val + right_val;
                2'b01: eval_tree = left_val - right_val;
                2'b10: eval_tree = left_val * right_val;
                2'b11: eval_tree = left_val >>> right_val[5:0]; 
                // 註：規格書寫 Right child [37:32] [cite: 179]，
                // 因為 Right child 如果是 Number，值存在它原始資料的 [62:32]，
                // 所以它實際值的最底層 6 bits (即 right_val[5:0])，剛好對應原始記憶體位址的 [37:32]。
                default: eval_tree = 64'd0;
            endcase
        end
    end
endfunction

// 宣告排序用的暫存陣列
// sort_data 儲存完整的 64-bit 資料
// sort_key  儲存用於排序的 [62:32] 31-bit 數值
// sort_addr 儲存原始位址 (用於穩定排序的 Tie-breaking)
reg [63:0] sort_data [0:1023];
reg [30:0] sort_key  [0:1023];
reg [15:0] sort_addr [0:1023];

integer b, c, idx;

function automatic pair_less;
    input [30:0] key_a;
    input [15:0] addr_a;
    input [30:0] key_b;
    input [15:0] addr_b;
    begin
        pair_less = (key_a < key_b) || ((key_a == key_b) && (addr_a < addr_b));
    end
endfunction

function automatic pair_greater;
    input [30:0] key_a;
    input [15:0] addr_a;
    input [30:0] key_b;
    input [15:0] addr_b;
    begin
        pair_greater = (key_a > key_b) || ((key_a == key_b) && (addr_a > addr_b));
    end
endfunction

task automatic quick_sort;
    input integer left;
    input integer right;

    integer i, j;
    integer pivot_idx;
    reg [30:0] pivot_key;
    reg [15:0] pivot_addr;
    reg [63:0] temp_data;
    reg [30:0] temp_key;
    reg [15:0] temp_addr;
    begin
        i = left;
        j = right;
        pivot_idx = (left + right) >> 1;
        pivot_key = sort_key[pivot_idx];
        pivot_addr = sort_addr[pivot_idx];

        while (i <= j) begin
            while (i <= right && pair_less(sort_key[i], sort_addr[i], pivot_key, pivot_addr)) begin
                i = i + 1;
            end
            while (j >= left && pair_greater(sort_key[j], sort_addr[j], pivot_key, pivot_addr)) begin
                j = j - 1;
            end

            if (i <= j) begin
                temp_key = sort_key[i];
                sort_key[i] = sort_key[j];
                sort_key[j] = temp_key;

                temp_data = sort_data[i];
                sort_data[i] = sort_data[j];
                sort_data[j] = temp_data;

                temp_addr = sort_addr[i];
                sort_addr[i] = sort_addr[j];
                sort_addr[j] = temp_addr;

                i = i + 1;
                j = j - 1;
            end
        end

        if (left < j) quick_sort(left, j);
        if (i < right) quick_sort(i, right);
    end
endtask
// =========================================================================
// Testcase Generation Task (Seperated from input_task for better readability and modularity)
// =========================================================================
integer rand_val;
task gen_testcase; begin
    // 1. 決定測資間隔 (2 ~ 4 cycles)
    wait_gap = $urandom_range(2, 4);
    repeat(wait_gap) @(negedge clk);

    // 2. 決定當下 Mode (遵守 10:10:30:30 比例)
    rand_val = $urandom_range(0, 79);
    if      (rand_val < 10) mode_rand = 2'd0; // READ
    else if (rand_val < 20) mode_rand = 2'd1; // WRITE
    else if (rand_val < 50) mode_rand = 2'd2; // CALC
    else                     mode_rand = 2'd3; // SORT
    // mode_rand = 2'd3;

    // 3. 根據 Mode 生成對應的隨機位址 (遵守 Row 範圍限制)
    case (mode_rand)
        2'd0: begin // READ
            bank_rand    = $urandom_range(0, 3);
            src_row_rand = $urandom_range(0, 62);
            dst_row_rand = 6'bx;
        end
        2'd1: begin // WRITE
            bank_rand    = $urandom_range(0, 3);
            src_row_rand = 6'bx;
            dst_row_rand = $urandom_range(32, 62);
            // Generate a random 64 bit number
            for (col_idx=0; col_idx<256; col_idx=col_idx+1) begin
                // in_data_rand[col_idx] = { $urandom_range(0, 32'hffffffff), $urandom_range(0, 32'hffffffff) };
                in_data_rand[col_idx] = { $urandom(), $urandom() };
                // in_data_rand[col_idx] = { $urandom() & 32'h3FFFFFFF, $urandom() };
                // 這裡也需要把這筆 in_data 存進 PATTERN 自己的 golden 陣列中！
                golden_DRAM[{bank_rand, dst_row_rand, col_idx[7:0]}] = in_data_rand[col_idx]; // 存到對應的位址中
            end
        end
        2'd2: begin // CALC
            bank_rand    = 2'bx;
            src_row_rand = $urandom_range(0, 31);
            dst_row_rand = 6'bx;
            
            // compute calc_mode_golden
            // 依序計算 Bank 0 到 Bank 3 的四棵樹
            for (b = 0; b < 4; b = b + 1) begin
                // 根節點的位址為 {Bank, in_src_row, Column 0}
                calc_mode_golden[b] = eval_tree({b[1:0], src_row_rand, 8'd0});
            end
        end
        2'd3: begin // SORT
            bank_rand    = 2'bx;
            src_row_rand = $urandom_range(0, 62);
            dst_row_rand = $urandom_range(32, 62);
            while (src_row_rand === dst_row_rand) begin
                dst_row_rand = $urandom_range(32, 62);
            end

            // 1. 收集 1024 筆資料
            idx = 0;
            for (b = 0; b < 4; b = b + 1) begin
                for (c = 0; c < 256; c = c + 1) begin
                    sort_data[idx] = golden_DRAM[{b[1:0], src_row_rand, c[7:0]}];
                    sort_key[idx]  = sort_data[idx][62:32]; // 提取 31-bit 作為排序鍵值
                    sort_addr[idx] = {b[1:0], src_row_rand, c[7:0]}; // 記錄原始位址
                    idx = idx + 1;
                end
            end

            // 2. 進行快速排序 (Quick Sort)
            quick_sort(0, 1023);

            // 3. 將排序好的 1024 筆資料寫回 golden_DRAM 的 dst_row_rand
            idx = 0;
            for (b = 0; b < 4; b = b + 1) begin
                for (c = 0; c < 256; c = c + 1) begin
                    golden_DRAM[{b[1:0], dst_row_rand, c[7:0]}] = sort_data[idx];
                    idx = idx + 1;
                end
            end
            
        end
        default: begin
            $display("*************************************************************************");
            $display(" Pattern Error: Invalid Mode at gen_testcase! ");
            $display("*************************************************************************");
            $finish;
            bank_rand    = 2'bx;
            src_row_rand = 6'bx;
            dst_row_rand = 6'bx;
            // in_data_rand = 64'bx;
        end
    endcase

end endtask

// ========================================================================
// Compare the output with golden, and activate err flags if errors are detected
// =======================================================================
integer cycle_idx, bank_idx;
integer file;
task check_ans_task; begin
    case(mode_rand)
    2'd0:begin // 256 cycles
        // 依序輸出 256 筆資料：必須等於DRAM指定的 in_bank 與 in_src_row (範圍 0~62) 內 Column 0~255 的 Golden 資料
        
        cycle_idx = 0;
        for (cycle_idx = 0; cycle_idx < 256; cycle_idx = cycle_idx + 1) begin
            if (out_cycle_data[cycle_idx] !== golden_DRAM[{bank_rand, src_row_rand, cycle_idx[7:0]}]) begin
                err_main4 = 1'b1; // 資料錯誤，觸發 MAIN-4 錯誤
            end
        end

    end
    2'd1:begin // 1 cycle
        // 檢查DRAM指定的 in_bank 中 in_dst_row (範圍 32~62) 裡的 Column 0~255 。預期值必須與你剛剛連續餵入的 256 筆 64-bit in_data 完全相同
        // check actual DRAM value vs golden_DRAM
        for (col_idx=0; col_idx < 256; col_idx = col_idx + 1) begin
            if (u_DRAM.DRAM[{bank_rand, dst_row_rand, col_idx[7:0]}] !== golden_DRAM[{bank_rand, dst_row_rand, col_idx[7:0]}]) begin
                $display("Mode: WRITE, Cycle: %d", cycle_idx);
                $display("Data mismatch at Bank %d, Row %d, Col %d! Expected: 0x%h, Got: 0x%h", bank_rand, dst_row_rand, col_idx, golden_DRAM[{bank_rand, dst_row_rand, col_idx[7:0]}], u_DRAM.DRAM[{bank_rand, dst_row_rand, col_idx[7:0]}]);
                err_main5 = 1'b1; // 資料錯誤，觸發 MAIN-5 錯誤
            end
        end
    end
    2'd2:begin // 4 cycles
        // check if the 4 out_data match the pre-computed calc_mode_golden
         for (cycle_idx = 0; cycle_idx < 4; cycle_idx = cycle_idx + 1) begin
            if (out_cycle_data[cycle_idx] !== calc_mode_golden[cycle_idx]) begin
                err_main4 = 1'b1; // 資料錯誤，觸發 MAIN-4 錯誤
            end
        end 
        
    end
    2'd3:begin // 1 cycle
        // 檢查 4 個 Bank (B0, B1, B2, B3) 的 in_dst_row (範圍 32~62) 的 Column 0~255 的 DRAM data
        for (bank_idx = 0; bank_idx < 4; bank_idx = bank_idx + 1) begin
            for (col_idx = 0; col_idx < 256; col_idx = col_idx + 1) begin
                if (u_DRAM.DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}] !== golden_DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}]) begin
                    // Capture failure data in debug registers for waveform inspection
                    sort_fail_actual_data   = u_DRAM.DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}];
                    // look at col_idx -1
                    sort_fail_actual_data_LAST = u_DRAM.DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0] - 1}];
                    sort_fail_expected_data = golden_DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}];
                    sort_fail_expected_data_LAST = golden_DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0] - 1}];
                    sort_fail_address       = {bank_idx[1:0], dst_row_rand, col_idx[7:0]};
                    sort_fail_bank_idx      = bank_idx;
                    sort_fail_row_idx       = dst_row_rand;
                    sort_fail_col_idx       = col_idx[7:0];
                    
                    $display("Mode: SORT, Error at Array Index: %d", col_idx + bank_idx*256);
                    $display("Source Row for this SORT pattern: %d", src_row_rand);
                    $display("Data mismatch at Bank %d, Row %d, Col %d! Expected: 0x%h, Got: 0x%h", bank_idx, dst_row_rand, col_idx, golden_DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}], u_DRAM.DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}]);
                    // dump the entire sorted row into a .txt file for debugging
                    file = $fopen($sformatf("sorted_output_bank%d_row%d.txt", bank_idx, dst_row_rand), "w");
                    for (col_idx = 0; col_idx < 256; col_idx = col_idx + 1) begin
                        $fwrite(file, "0x%h\n", u_DRAM.DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}]);
                    end
                    // dump the golden sorted row into a .txt file for debugging
                    file = $fopen($sformatf("golden_sorted_bank%d_row%d.txt", bank_idx, dst_row_rand), "w");
                    for (col_idx = 0; col_idx < 256; col_idx = col_idx + 1) begin
                        $fwrite(file, "0x%h\n", golden_DRAM[{bank_idx[1:0], dst_row_rand, col_idx[7:0]}]);
                    end
                    $fclose(file);

                    err_main5 = 1'b1; // 資料錯誤，觸發 MAIN-5 錯誤
                end
            end
        end
    end
    default: begin
        // print error msg
        $display("*************************************************************************");
        $display(" Pattern Error: Invalid Mode at check_ans_task! ");
        $display("*************************************************************************");
        $finish;
    end
    endcase
end endtask

// ========================================================================
// The flow ctrl part of the input procedure
// =======================================================================
task run_pat_task; begin

    gen_testcase;

    // 發送 in_mode_valid (1 cycle)
    in_mode_valid = 1'b1;
    in_mode = mode_rand;

    in_valid = 1'b0;
    in_data = 64'bx;
    @(negedge clk);
    
    // 發送 in_valid 與位址/資料
    in_mode_valid = 1'b0;
    in_valid = 1'b1;
    
    // WRITE mode
    if (mode_rand === 2'd1) begin
        // WRITE: 連續餵 256 筆資料
        for (col_idx = 0; col_idx < 256; col_idx = col_idx + 1) begin
            // 產生 64-bit 亂數 (Verilog urandom 只有 32-bit，需拼接)
            in_data = in_data_rand[col_idx];
            in_bank = bank_rand;
            in_src_row = src_row_rand;
            in_dst_row = dst_row_rand;
            @(negedge clk);
        end
    end else begin
        // READ, CALC, SORT: 只餵 1 拍
        in_bank = bank_rand;
        in_src_row = src_row_rand;
        in_dst_row = dst_row_rand;
        in_data = 64'bx;
        @(negedge clk);
    end

    // $display("Input fed for Mode %d (Bank: %d, Src Row: %d, Dst Row: %d). Waiting for output...", mode_rand, bank_rand, src_row_rand, dst_row_rand);

    // 6. 結束輸入，全部歸 X
    in_valid = 1'b0;
    in_bank = 2'bx;
    in_src_row = 6'bx;
    in_dst_row = 6'bx;
    in_data = 64'bx;
    in_mode = 2'bx;

    // $display("Checking output for Mode %d (Bank: %d, Src Row: %d, Dst Row: %d)...", mode_rand, bank_rand, src_row_rand, dst_row_rand);
    check_output_task;
    
end endtask


task reset_task; begin
    // 1. Initialize all input signals, including the reset signal (rst_n)
    rst_n = 1;
    in_valid = 0;
    in_mode_valid = 0;
    in_mode = 2'bx;
    in_bank = 2'bx;
    in_src_row = 6'bx;
    in_dst_row = 6'bx;
    in_data = 64'bx;

    #(CYCLE/2.0); 
    rst_n = 0; // 觸發非同步重置
    sys_rst = 1; // indicate that the system has been reset at least once

    // 2. 規格書嚴格規定：在 reset 拉低後等待 200ns 進行檢查
    #(200.0); 

    // 3. 檢查 HARVESTER 的所有 output port 是否已歸零
    if (// Harvester (Master) AXI Outputs
        aw_valid !== 0 || aw_addr !== 0 || 
        w_valid  !== 0 || w_data  !== 0 || 
        b_ready  !== 0 || 
        ar_valid !== 0 || ar_addr !== 0 || 
        r_ready  !== 0 || 
        // DRAM_CTRL (Slave) AXI Outputs
        aw_ready !== 0 || 
        w_ready  !== 0 || 
        b_valid  !== 0 || b_resp  !== 0 || 
        ar_ready !== 0 || 
        r_valid  !== 0 || r_data  !== 0 || r_resp !== 0 ||
        // Harvester Normal Outputs
        out_valid !== 0 || out_data !== 0) begin
        
        err_main1 = 1'b1; // 觸發旗標，Master Checker 會在此刻立刻接手中斷
    end

    // 4. 結束 reset 狀態
    @(negedge clk);
    rst_n = 1;

end endtask

// ==========================================================================
// SPECIFICATION FAILURE TASKS (Ordered by Priority)
// ==========================================================================

// +-------------------------------------------------------------------------
// SPEC MAIN-1 Checks
// +-------------------------------------------------------------------------
// Priority 1
task SPEC_MAIN1_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC MAIN-1 FAIL                            *");
    $display("* All output signals should be reset after rst_n is asserted!      *");
    $display("*************************************************************************");
    $finish;
end endtask

// +-------------------------------------------------------------------------
// SPEC AXI-1 Checks
// +--------------------------------------------------------------------------
// 使用 negedge clk 來避開訊號過渡期的毛刺 (Glitches)
always @(negedge clk) begin
    // 只有在系統沒有被 reset 的時候才檢查一般運作邏輯
    if (rst_n === 1'b1 && sys_rst === 1'b1) begin
        
        // 檢查 AW 通道 (Master 輸出)
        if (aw_valid === 1'b0 && aw_addr !== 32'd0) begin
            $display("SPEC AXI-1 FAIL: AW channel has invalid address when AW_VALID is low! AW_ADDR = 0x%h", aw_addr);
            err_axi1 = 1'b1;
        end
        
        // 檢查 W 通道 (Master 輸出)
        if (w_valid === 1'b0 && w_data !== 64'd0) begin
            $display("SPEC AXI-1 FAIL: W channel has invalid data when W_VALID is low! W_DATA = 0x%h", w_data);
            err_axi1 = 1'b1;
        end
        
        // 檢查 AR 通道 (Master 輸出)
        if (ar_valid === 1'b0 && ar_addr !== 32'd0) begin
            $display("SPEC AXI-1 FAIL: AR channel has invalid address when AR_VALID is low! AR_ADDR = 0x%h", ar_addr);
            err_axi1 = 1'b1;
        end
        
        // 檢查 B 通道 (Slave 輸出)
        if (b_valid === 1'b0 && b_resp !== 2'd0) begin
            $display("SPEC AXI-1 FAIL: B channel has invalid response when B_VALID is low! B_RESP = 0x%h", b_resp);
            err_axi1 = 1'b1;
        end
        
        // 檢查 R 通道 (Slave 輸出)
        if (r_valid === 1'b0 && (r_data !== 64'd0 || r_resp !== 2'd0)) begin
            $display("SPEC AXI-1 FAIL: R channel has invalid data or response when R_VALID is low! R_DATA = 0x%h, R_RESP = 0x%h", r_data, r_resp);
            err_axi1 = 1'b1;
        end

    end
end

task SPEC_AXI1_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-1 FAIL                            *");
    $display("* Data, address and response should be reset when valid is low.    *");
    $display("*************************************************************************");
    $finish;
end endtask

// +-------------------------------------------------------------------------
// SPEC AXI-2 Checks
// +-------------------------------------------------------------------------
// 儲存上一個 cycle 的 Valid 與 Ready 狀態
reg aw_valid_d, aw_ready_d;
reg w_valid_d,  w_ready_d;
reg b_valid_d,  b_ready_d;
reg ar_valid_d, ar_ready_d;
reg r_valid_d,  r_ready_d;
// 儲存上一個 cycle 的 Payload (資料內容)
reg [31:0] aw_addr_d;
reg [63:0] w_data_d;
reg [1:0]  b_resp_d;
reg [31:0] ar_addr_d;
reg [63:0] r_data_d;
reg [1:0]  r_resp_d;

always @(negedge clk) begin
    if (rst_n === 1'b0) begin
        // Reset 期間，清除所有歷史紀錄
        aw_valid_d <= 0; aw_ready_d <= 0; aw_addr_d <= 0;
        w_valid_d  <= 0; w_ready_d  <= 0; w_data_d  <= 0;
        b_valid_d  <= 0; b_ready_d  <= 0; b_resp_d  <= 0;
        ar_valid_d <= 0; ar_ready_d <= 0; ar_addr_d <= 0;
        r_valid_d  <= 0; r_ready_d  <= 0; r_data_d  <= 0;
        r_resp_d   <= 0;
    end else begin
        // =========================================================
        // 1. 執行穩定度檢查 (Check Stability)
        // =========================================================
        
        // 【AW 通道檢查】
        if (aw_valid_d === 1'b1 && aw_ready_d === 1'b0) begin
            if (aw_valid !== 1'b1 || aw_addr !== aw_addr_d) begin
                // print the timestamp and the error details for debugging
                $display("SPEC AXI-2 FAIL at time %t: AW channel signals changed during handshake! Previous AW_VALID = %b, AW_ADDR = 0x%h; Current AW_VALID = %b, AW_ADDR = 0x%h", $time, aw_valid_d, aw_addr_d, aw_valid, aw_addr);
                err_axi2 = 1'b1;
            end
        end

        // 【W 通道檢查】
        if (w_valid_d === 1'b1 && w_ready_d === 1'b0) begin
            if (w_valid !== 1'b1 || w_data !== w_data_d) begin
                $display("SPEC AXI-2 FAIL at time %t: W channel signals changed during handshake! Previous W_VALID = %b, W_DATA = 0x%h; Current W_VALID = %b, W_DATA = 0x%h", $time, w_valid_d, w_data_d, w_valid, w_data);
                err_axi2 = 1'b1;
            end
        end

        // 【AR 通道檢查】
        if (ar_valid_d === 1'b1 && ar_ready_d === 1'b0) begin
            if (ar_valid !== 1'b1 || ar_addr !== ar_addr_d) begin
                $display("SPEC AXI-2 FAIL at time %t: AR channel signals changed during handshake! Previous AR_VALID = %b, AR_ADDR = 0x%h; Current AR_VALID = %b, AR_ADDR = 0x%h", $time, ar_valid_d, ar_addr_d, ar_valid, ar_addr);
                err_axi2 = 1'b1;
            end
        end

        // 【B 通道檢查】
        if (b_valid_d === 1'b1 && b_ready_d === 1'b0) begin
            if (b_valid !== 1'b1 || b_resp !== b_resp_d) begin
                $display("SPEC AXI-2 FAIL at time %t: B channel signals changed during handshake! Previous B_VALID = %b, B_RESP = 0x%h; Current B_VALID = %b, B_RESP = 0x%h", $time, b_valid_d, b_resp_d, b_valid, b_resp);
                err_axi2 = 1'b1;
            end
        end

        // 【R 通道檢查】
        if (r_valid_d === 1'b1 && r_ready_d === 1'b0) begin
            if (r_valid !== 1'b1 || r_data !== r_data_d || r_resp !== r_resp_d) begin
                $display("SPEC AXI-2 FAIL at time %t: R channel signals changed during handshake! Previous R_VALID = %b, R_DATA = 0x%h, R_RESP = 0x%h; Current R_VALID = %b, R_DATA = 0x%h, R_RESP = 0x%h", $time, r_valid_d, r_data_d, r_resp_d, r_valid, r_data, r_resp);
                err_axi2 = 1'b1;
            end
        end

        // =========================================================
        // 2. 更新歷史紀錄，供下一個 cycle 檢查使用 (Update History)
        // =========================================================
        aw_valid_d <= aw_valid; aw_ready_d <= aw_ready; aw_addr_d <= aw_addr;
        w_valid_d  <= w_valid;  w_ready_d  <= w_ready;  w_data_d  <= w_data;
        b_valid_d  <= b_valid;  b_ready_d  <= b_ready;  b_resp_d  <= b_resp;
        ar_valid_d <= ar_valid; ar_ready_d <= ar_ready; ar_addr_d <= ar_addr;
        r_valid_d  <= r_valid;  r_ready_d  <= r_ready;  r_data_d  <= r_data;
        r_resp_d   <= r_resp;
    end
end

task SPEC_AXI2_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-2 FAIL                            *");
    $display("* AW/W/B/AR/R channel signals must be stable before receiving response. *");
    $display("*************************************************************************");
    $finish;
end endtask

// +-------------------------------------------------------------------------
// SPEC AXI-3 Checks
// +-------------------------------------------------------------------------

// 宣告一個計數器，記錄「已經發出位址(AW)，但還沒給資料(W)」的數量
reg [7:0] aw_w_unmatched_cnt;

always @(negedge clk) begin
    if (rst_n === 1'b0) begin
        aw_w_unmatched_cnt <= 8'd0;
    end else begin
        // =========================================================
        // 1. 維護未匹配的 AW 數量
        // =========================================================
        case ({ (aw_valid && aw_ready), (w_valid && w_ready) })
            2'b10: aw_w_unmatched_cnt <= aw_w_unmatched_cnt + 1; // AW 完成交握，等待 W
            2'b01: aw_w_unmatched_cnt <= aw_w_unmatched_cnt - 1; // W 完成交握，消耗掉一個 AW
            // 2'b11: 同時交握，一加一減抵銷，計數器不變
            // 2'b00: 都沒交握，計數器不變
            default: aw_w_unmatched_cnt <= aw_w_unmatched_cnt; 
        endcase

        // =========================================================
        // 2. SPEC AXI-3 核心檢查 (Dependency Check)
        // =========================================================
        // 如果 w_valid 為 1，我們必須確保「有位址可以配對」。
        // 合法的配對來源只有兩個：
        //   A. 此時 aw_valid 也是 1 (同一個 cycle 一起發送)
        //   B. 之前已經有 aw 交握過了 (計數器 > 0)
        // 如果兩者皆非，就代表發生了「沒有 AW 卻想送 W」的嚴重違例！
        
        if (w_valid === 1'b1 && aw_valid === 1'b0 && aw_w_unmatched_cnt === 8'd0) begin
            err_axi3 = 1'b1;
        end
    end
end

task SPEC_AXI3_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-3 FAIL                            *");
    $display("* w_valid asserted without corresponding aw_valid is not allowed.    *");
    $display("*************************************************************************");
    $finish;
end endtask

// ==========================================================================
// SPEC AXI-4: Address Range Check
// ==========================================================================
always @(negedge clk) begin
    if (rst_n === 1'b1 && sys_rst === 1'b1) begin
        // 寫入位址檢查
        if (aw_valid === 1'b1 && aw_addr > 32'd65535) begin
            err_axi4 = 1'b1;
        end
        // 讀取位址檢查
        if (ar_valid === 1'b1 && ar_addr > 32'd65535) begin
            err_axi4 = 1'b1;
        end
    end
end

task SPEC_AXI4_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-4 FAIL                            *");
    $display("* The address should be within the legal range (0~65535).     *");
    $display("*************************************************************************");
    $finish;
end endtask

// ==========================================================================
// SPEC AXI-5: Timeout Check 1 (Ready signal timeout)
// ==========================================================================
reg [7:0] cnt_aw_rdy, cnt_w_rdy, cnt_b_rdy, cnt_ar_rdy, cnt_r_rdy;
reg aw_wait_flag, w_wait_flag, b_wait_flag, ar_wait_flag, r_wait_flag;

always @(negedge clk) begin
    if (rst_n === 1'b0) begin
        cnt_aw_rdy <= 0; cnt_w_rdy <= 0; cnt_b_rdy <= 0; 
        cnt_ar_rdy <= 0; cnt_r_rdy <= 0;
        aw_wait_flag <= 0; w_wait_flag <= 0; b_wait_flag <= 0;
        ar_wait_flag <= 0; r_wait_flag <= 0;
    end else begin
        // -----------------------------------------------------------
        // AW Channel (0~50 cycles)
        // -----------------------------------------------------------
        // 嚴格偵測 valid 拉高 (0 -> 1) 且尚未 ready 時，才進入等待狀態
        if (aw_valid && ~aw_valid_d && ~aw_ready) begin
            aw_wait_flag <= 1'b1;
            cnt_aw_rdy <= 1;
        end else if (aw_wait_flag) begin
            if (aw_ready) begin
                aw_wait_flag <= 1'b0; // 交握成功，解除等待
                cnt_aw_rdy <= 0;
            end else begin
                if (cnt_aw_rdy >= 50) err_axi5 = 1'b1;
                cnt_aw_rdy <= cnt_aw_rdy + 1;
            end
        end else begin
            cnt_aw_rdy <= 0;
        end
        if (~aw_valid) aw_wait_flag <= 1'b0; // 防呆：若 valid 異常降下，解除等待

        // -----------------------------------------------------------
        // W Channel (0~100 cycles)
        // -----------------------------------------------------------
        if (w_valid && ~w_valid_d && ~w_ready) begin
            w_wait_flag <= 1'b1;
            cnt_w_rdy <= 1;
        end else if (w_wait_flag) begin
            if (w_ready) begin
                w_wait_flag <= 1'b0;
                cnt_w_rdy <= 0;
            end else begin
                if (cnt_w_rdy >= 100) err_axi5 = 1'b1;
                cnt_w_rdy <= cnt_w_rdy + 1;
            end
        end else begin
            cnt_w_rdy <= 0;
        end
        if (~w_valid) w_wait_flag <= 1'b0;

        // -----------------------------------------------------------
        // B Channel (0~100 cycles)
        // -----------------------------------------------------------
        if (b_valid && ~b_valid_d && ~b_ready) begin
            b_wait_flag <= 1'b1;
            cnt_b_rdy <= 1;
        end else if (b_wait_flag) begin
            if (b_ready) begin
                b_wait_flag <= 1'b0;
                cnt_b_rdy <= 0;
            end else begin
                if (cnt_b_rdy >= 100) err_axi5 = 1'b1;
                cnt_b_rdy <= cnt_b_rdy + 1;
            end
        end else begin
            cnt_b_rdy <= 0;
        end
        if (~b_valid) b_wait_flag <= 1'b0;

        // -----------------------------------------------------------
        // AR Channel (0~50 cycles)
        // -----------------------------------------------------------
        if (ar_valid && ~ar_valid_d && ~ar_ready) begin
            ar_wait_flag <= 1'b1;
            cnt_ar_rdy <= 1;
        end else if (ar_wait_flag) begin
            if (ar_ready) begin
                ar_wait_flag <= 1'b0;
                cnt_ar_rdy <= 0;
            end else begin
                if (cnt_ar_rdy >= 50) err_axi5 = 1'b1;
                cnt_ar_rdy <= cnt_ar_rdy + 1;
            end
        end else begin
            cnt_ar_rdy <= 0;
        end
        if (~ar_valid) ar_wait_flag <= 1'b0;

        // -----------------------------------------------------------
        // R Channel (0~100 cycles)
        // -----------------------------------------------------------
        if (r_valid && ~r_valid_d && ~r_ready) begin
            r_wait_flag <= 1'b1;
            cnt_r_rdy <= 1;
        end else if (r_wait_flag) begin
            if (r_ready) begin
                r_wait_flag <= 1'b0;
                cnt_r_rdy <= 0;
            end else begin
                if (cnt_r_rdy >= 100) err_axi5 = 1'b1;
                cnt_r_rdy <= cnt_r_rdy + 1;
            end
        end else begin
            cnt_r_rdy <= 0;
        end
        if (~r_valid) r_wait_flag <= 1'b0;
    end
end
task SPEC_AXI5_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-5 FAIL                            *");
    $display("* The ready signal must be asserted within 50/100 cycles.         *");
    $display("*************************************************************************");
    $finish;
end endtask

// ==========================================================================
// SPEC AXI-6: Timeout Check 2 (Cross-channel phase delay)
// ==========================================================================
reg [7:0] w_b_unmatched_cnt;
reg [7:0] ar_r_unmatched_cnt;
reg [7:0] cnt_aw_w, cnt_w_b, cnt_ar_r;

always @(negedge clk) begin
    if (rst_n === 1'b0) begin
        w_b_unmatched_cnt  <= 0;
        ar_r_unmatched_cnt <= 0;
        cnt_aw_w <= 0; cnt_w_b <= 0; cnt_ar_r <= 0;
    end else begin
        // ---------------------------------------------------------
        // 1. 維護跨通道的未匹配數量 (Outstanding 追蹤)
        // ---------------------------------------------------------
        // 追蹤 W 到 B 的進度
        case ({(w_valid && w_ready), (b_valid && b_ready)})
            2'b10: w_b_unmatched_cnt <= w_b_unmatched_cnt + 1; // W 送完，等待 B
            2'b01: w_b_unmatched_cnt <= w_b_unmatched_cnt - 1; // B 接收完畢，結案
            // 2'b11: 同時交握，一加一減抵銷，計數器不變
            // 2'b00: 都沒交握，計數器不變
            default: w_b_unmatched_cnt <= w_b_unmatched_cnt;
        endcase

        // 追蹤 AR 到 R 的進度
        case ({(ar_valid && ar_ready), (r_valid && r_ready)})
            2'b10: ar_r_unmatched_cnt <= ar_r_unmatched_cnt + 1; // AR 送完，等待 R
            2'b01: ar_r_unmatched_cnt <= ar_r_unmatched_cnt - 1; // R 接收完畢，結案
            default: ar_r_unmatched_cnt <= ar_r_unmatched_cnt;
        endcase

        // ---------------------------------------------------------
        // 2. 檢查 150 cycles 延遲限制
        // ---------------------------------------------------------
        // AW 握手後 -> 等待 W 握手
        if (aw_w_unmatched_cnt > 0) begin
            if (w_valid && w_ready) cnt_aw_w <= 0;
            else begin
                if (cnt_aw_w >= 150)begin
                    $display("AW-W unmatched count: %d, Cycle count: %d", aw_w_unmatched_cnt, cnt_aw_w);
                    err_axi6 = 1'b1;
                end
                cnt_aw_w <= cnt_aw_w + 1;
            end
            // $display("AW-W unmatched count: %d, Cycle count: %d", aw_w_unmatched_cnt, cnt_aw_w);
        end else cnt_aw_w <= 0;

        // W 握手後 -> 等待 B_VALID
        if (w_b_unmatched_cnt > 0) begin
            // 規格書定義 B 通道只要 b_valid 出現即達成條件
            if (b_valid) cnt_w_b <= 0; 
            else begin
                if (cnt_w_b >= 150) begin 
                    $display("W-B unmatched count: %d, Cycle count: %d", w_b_unmatched_cnt, cnt_w_b);
                    err_axi6 = 1'b1;
                end
                cnt_w_b <= cnt_w_b + 1;
            end
            // $display("W-B unmatched count: %d, Cycle count: %d", w_b_unmatched_cnt, cnt_w_b);
        end else cnt_w_b <= 0;

        // AR 握手後 -> 等待 R 握手
        if (ar_r_unmatched_cnt > 0) begin
            if (r_valid && r_ready) cnt_ar_r <= 0;
            else begin
                if (cnt_ar_r >= 150) begin 
                    err_axi6 = 1'b1; 
                    $display("AR-R unmatched count: %d, Cycle count: %d", ar_r_unmatched_cnt, cnt_ar_r);
                end
                cnt_ar_r <= cnt_ar_r + 1;
            end
            

        end else cnt_ar_r <= 0;
    end
end

task SPEC_AXI6_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC AXI-6 FAIL                            *");
    $display("* W/B/R channels must be asserted within 150 cycles after handshake.    *");
    $display("*************************************************************************");
    $finish;
end endtask

// Priority 8
task SPEC_MAIN2_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC MAIN-2 FAIL                            *");
    $display("* The execution latency is limited in 10000 cycles.         *");
    $display("*************************************************************************");
    $finish;
end endtask

// Priority 9
task SPEC_MAIN3_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC MAIN-3 FAIL                            *");
    $display("* The out_valid and out_data must be asserted in relative cycles. *");
    // display expected and actual valid cycle count for debugging
    $display("* Expected valid cycles: %d, Actual valid cycles: %d *", expected_cycles, valid_count);
    $display("*************************************************************************");
    $finish;
end endtask

// Priority 10
task SPEC_MAIN4_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC MAIN-4 FAIL                            *");
    $display("* The out_data should be correct when out_valid is high.     *");
    $display(" Error detected at output cycle %d. ", valid_count);
    $display("* Expected data: %h, Actual data: %h *", expected_data, out_data);
    $display("*************************************************************************");
    $finish;
end endtask

// Priority 11
task SPEC_MAIN5_FAIL; begin
    // fail_icon_task;
    $display("*************************************************************************");
    $display("* SPEC MAIN-5 FAIL                            *");
    $display("* The data in the DRAM should be correct when out_valid is high. *");
    $display(" Error detected at output cycle %d. ", valid_count);
    $display("*************************************************************************");
    $finish;
end endtask

task pass_icon_task; begin
    $display("\033[37m                                                                                                                                          ");        
    $display("\033[37m                                                                                \033[32m      :BBQvi.                                              ");        
    $display("\033[37m                                                              .i7ssrvs7         \033[32m     BBBBBBBBQi                                           ");        
    $display("\033[37m                        .:r7rrrr:::.        .::::::...   .i7vr:.      .B:       \033[32m    :BBBP :7BBBB.                                         ");        
    $display("\033[37m                      .Kv.........:rrvYr7v7rr:.....:rrirJr.   .rgBBBBg  Bi      \033[32m    BBBB     BBBB                                         ");        
    $display("\033[37m                     7Q  :rubEPUri:.       ..:irrii:..    :bBBBBBBBBBBB  B      \033[32m   iBBBv     BBBB       vBr                               ");        
    $display("\033[37m                    7B  BBBBBBBBBBBBBBB::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB :R     \033[32m   BBBBBKrirBBBB.     :BBBBBB:                            ");        
    $display("\033[37m                   Jd .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: Bi    \033[32m  rBBBBBBBBBBBR.    .BBBM:BBB                             ");        
    $display("\033[37m                  uZ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B    \033[32m  BBBB   .::.      EBBBi :BBU                             ");        
    $display("\033[37m                 7B .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  B    \033[32m MBBBr           vBBBu   BBB.                             ");        
    $display("\033[37m                .B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: JJ   \033[32m i7PB          iBBBBB.  iBBB                              ");        
    $display("\033[37m                B. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  Lu             \033[32m  vBBBBPBBBBPBBB7       .7QBB5i                ");        
    $display("\033[37m               Y1 KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBi XBBBBBBBi :B            \033[32m :RBBB.  .rBBBBB.      rBBBBBBBB7              ");        
    $display("\033[37m              :B .BBBBBBBBBBBBBsRBBBBBBBBBBBrQBBBBB. UBBBRrBBBBBBr 1BBBBBBBBB  B.          \033[32m    .       BBBB       BBBB  :BBBB             ");        
    $display("\033[37m              Bi BBBBBBBBBBBBBi :BBBBBBBBBBE .BBK.  .  .   QBBBBBBBBBBBBBBBBBB  Bi         \033[32m           rBBBr       BBBB    BBBU            ");        
    $display("\033[37m             .B .BBBBBBBBBBBBBBQBBBBBBBBBBBB       \033[38;2;242;172;172mBBv \033[37m.LBBBBBBBBBBBBBBBBBBBBBB. B7.:ii:   \033[32m           vBBB        .BBBB   :7i.            ");        
    $display("\033[37m            .B  PBBBBBBBBBBBBBBBBBBBBBBBBBBBBbYQB. \033[38;2;242;172;172mBB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBB  Jr:::rK7 \033[32m             .7  BBB7   iBBBg                  ");        
    $display("\033[37m           7M  PBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBB..i   .   v1                  \033[32mdBBB.   5BBBr                 ");        
    $display("\033[37m          sZ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBB iD2BBQL.                 \033[32m ZBBBr  EBBBv     YBBBBQi     ");        
    $display("\033[37m  .7YYUSIX5 .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBBBY.:.      :B                 \033[32m  iBBBBBBBBD     BBBBBBBBB.   ");        
    $display("\033[37m LB.        ..BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB. \033[38;2;242;172;172mBB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBMBBB. BP17si                 \033[32m    :LBBBr      vBBBi  5BBB   ");        
    $display("\033[37m  KvJPBBB :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: \033[38;2;242;172;172mZB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBsiJr .i7ssr:                \033[32m          ...   :BBB:   BBBu  ");        
    $display("\033[37m i7ii:.   ::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBj \033[38;2;242;172;172muBi \033[37mQBBBBBBBBBBBBBBBBBBBBBBBBi.ir      iB                \033[32m         .BBBi   BBBB   iMBu  ");        
    $display("\033[37mDB    .  vBdBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBg \033[38;2;242;172;172m7Bi \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBB rBrXPv.                \033[32m          BBBX   :BBBr        ");        
    $display("\033[37m :vQBBB. BQBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBQ \033[38;2;242;172;172miB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .L:ii::irrrrrrrr7jIr   \033[32m          .BBBv  :BBBQ        ");        
    $display("\033[37m :7:.   .. 5BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBr \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBB:            ..... ..YB. \033[32m           .BBBBBBBBB:        ");        
    $display("\033[37mBU  .:. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mB7 \033[37mgBBBBBBBBBBBBBBBBBBBBBBBBBB. gBBBBBBBBBBBBBBBBBB. BL \033[32m             rBBBBB1.         ");        
    $display("\033[37m rY7iB: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: \033[38;2;242;172;172mB7 \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBB. QBBBBBBBBBBBBBBBBBi  v5                                ");        
    $display("\033[37m     us EBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB \033[38;2;242;172;172mIr \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBgu7i.:BBBBBBBr Bu                                 ");        
    $display("\033[37m      B  7BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.\033[38;2;242;172;172m:i \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBv:.  .. :::  .rr    rB                                  ");        
    $display("\033[37m      us  .BBBBBBBBBBBBBQLXBBBBBBBBBBBBBBBBBBBBBBBBq  .BBBBBBBBBBBBBBBBBBBBBBBBBv  :iJ7vri:::1Jr..isJYr                                   ");        
    $display("\033[37m      B  BBBBBBB  MBBBM      qBBBBBBBBBBBBBBBBBBBBBB: BBBBBBBBBBBBBBBBBBBBBBBBBB  B:           iir:                                       ");        
    $display("\033[37m     iB iBBBBBBBL       BBBP. :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  B.                                                       ");        
    $display("\033[37m     P: BBBBBBBBBBB5v7gBBBBBB  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: Br                                                        ");        
    $display("\033[37m     B  BBBs 7BBBBBBBBBBBBBB7 :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B                                                         ");        
    $display("\033[37m    .B :BBBB.  EBBBBBQBBBBBJ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB. B.                                                         ");        
    $display("\033[37m    ij qBBBBBg          ..  .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B                                                          ");        
    $display("\033[37m    UY QBBBBBBBBSUSPDQL...iBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK EL                                                          ");        
    $display("\033[37m    B7 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: B:                                                          ");        
    $display("\033[37m    B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBYrBB vBBBBBBBBBBBBBBBBBBBBBBBB. Ls                                                          ");        
    $display("\033[37m    B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBi_  /UBBBBBBBBBBBBBBBBBBBBBBBBB. :B:                                                        ");        
    $display("\033[37m   rM .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  ..IBBBBBBBBBBBBBBBBQBBBBBBBBBB  B                                                        ");        
    $display("\033[37m   B  BBBBBBBBBdZBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPBBBBBBBBBBBBEji:..     sBBBBBBBr Br                                                       ");        
    $display("\033[37m  7B 7BBBBBBBr     .:vXQBBBBBBBBBBBBBBBBBBBBBBBBBQqui::..  ...i:i7777vi  BBBBBBr Bi                                                       ");        
    $display("\033[37m  Ki BBBBBBB  rY7vr:i....  .............:.....  ...:rii7vrr7r:..      7B  BBBBB  Bi                                                       ");        
    $display("\033[37m  B. BBBBBB  B:    .::ir77rrYLvvriiiiiiirvvY7rr77ri:..                 bU  iQBB:..rI                                                      ");        
    $display("\033[37m.S: 7BBBBP  B.                                                          vI7.  .:.  B.                                                     ");        
    $display("\033[37mB: ir:.   :B.                                                             :rvsUjUgU.                                                      ");        
    $display("\033[37mrMvrrirJKur                                                                                                                               \033[m");
end endtask


endmodule