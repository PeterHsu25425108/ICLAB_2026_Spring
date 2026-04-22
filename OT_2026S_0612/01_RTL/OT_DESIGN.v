// `define IDLE 2'd0
// `define IN_IMG 2'd1
// `define CALC 2'd2
// `define OUT 2'd3

module OT_DESIGN(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	in_data,
	
    in_valid_cmd,
	in_cmd,    
	
    // output signals
	out_valid,	
	out_data
);

input              clk;
input              rst_n;

input              in_valid_data;
input       [7:0]  in_data;

input              in_valid_cmd;
input      [9:0]  in_cmd;

output reg          out_valid;
output reg  [7:0]  out_data;

//==================================================================
// parameter & integer
//==================================================================

//==================================================================
// reg & wire
//==================================================================
// System states
localparam S_IDLE   = 2'd0;
localparam S_IN_IMG = 2'd1;
localparam S_CALC   = 2'd2;
localparam S_OUT    = 2'd3;

// CALC pipeline states
localparam C_IDLE         = 4'd0;
localparam C_AS_REQ1      = 4'd1; 
localparam C_AS_REQ2      = 4'd2; 
localparam C_SW_RD_T1     = 4'd3;  
localparam C_SW_RD_T2     = 4'd4;  
localparam C_SW_WAIT_T1   = 4'd5;  
localparam C_SW_WAIT_T2   = 4'd6;  
localparam C_SW_WR_T2     = 4'd7;  
localparam C_SW_WIN_WAIT1 = 4'd8;  
localparam C_SW_WIN_REQ   = 4'd9;  
localparam C_MP_REQ       = 4'd10; 
localparam C_DONE         = 4'd11; 

// FSM and basic registers
reg [1:0]  state, nxt_state;
reg [11:0] main_cnt;
reg [1:0]  opcode;
reg [3:0]  tgt1, tgt2;
reg [11:0] tgt1_offset, tgt2_offset;

// Synchronous SRAM control registers (FFs)
reg [11:0] mem0_addr_reg;
reg [7:0]  mem0_din_reg, mem0_dout_reg;
reg        mem0_web_reg;
wire [7:0] mem0_din, mem0_dout;
wire [11:0] mem0_addr;

// Calculation pipeline registers
reg [3:0]  calc_state;
reg [8:0]  pipe_cnt; 
reg [7:0]  tgt1_img, tgt2_img;
reg [15:0] sum1, sum2;
reg [7:0]  mp_max;
reg [8:0]  out_cnt;

// Output Buffer (256 pixels)
reg [7:0]  out_buf [0:255];
integer i;

//==================================================================
// Design Logic
//==================================================================

// 1. Main State Machine (Sequential)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= S_IN_IMG;
    else       state <= nxt_state;
end

// 2. Main State Machine (Combinational)
always @(*) begin
    nxt_state = state;
    case(state)
        S_IN_IMG: if(main_cnt == 4095 && in_valid_data) nxt_state = S_IDLE;
        S_IDLE:   if(in_valid_cmd)                      nxt_state = S_CALC;
        S_CALC:   if(calc_state == C_DONE)              nxt_state = S_OUT;
        S_OUT:    if(out_cnt == 255)                    nxt_state = S_IDLE;
    endcase
end

// 3. Input Image Counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        main_cnt <= 0;
    end else begin
        if(state == S_IN_IMG && in_valid_data) main_cnt <= main_cnt + 1;
        else if(state == S_IDLE)               main_cnt <= 0;
    end
end

// 4. Instruction Decode
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        opcode <= 0; tgt1 <= 0; tgt2 <= 0;
        tgt1_offset <= 0; tgt2_offset <= 0;
    end else if(state == S_IDLE && in_valid_cmd) begin
        opcode      <= in_cmd[9:8];
        tgt1        <= in_cmd[7:4];
        tgt2        <= in_cmd[3:0];
        // Shift left by 8 is equivalent to multiplying by 256 (image size)
        tgt1_offset <= {in_cmd[7:4], 8'd0}; 
        tgt2_offset <= {in_cmd[3:0], 8'd0};
    end
end

// 5. Main Computation FSM and SRAM FF Control
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        calc_state <= C_IDLE;
        pipe_cnt <= 0;
        mem0_addr_reg <= 0;
        mem0_din_reg <= 0;
        mem0_web_reg <= 1;
        tgt1_img <= 0; tgt2_img <= 0;
        sum1 <= 0; sum2 <= 0;
        mp_max <= 0;
    end else begin
        if (state == S_IN_IMG) begin
            mem0_web_reg <= ~in_valid_data;
            if (in_valid_data) begin
                mem0_addr_reg <= main_cnt;
                mem0_din_reg  <= in_data;
            end
        end 
        else if (state == S_IDLE) begin
            mem0_web_reg <= 1;
            pipe_cnt <= 0;
            sum1 <= 0; sum2 <= 0;
            
            if (in_valid_cmd) begin
                if (in_cmd[9:8] == 2'b00 || in_cmd[9:8] == 2'b01) begin
                    calc_state <= C_AS_REQ1;
                    mem0_addr_reg <= {in_cmd[7:4], 8'd0}; // Pre-fetch T1[0]
                end else if (in_cmd[9:8] == 2'b10) begin
                    calc_state <= C_SW_RD_T1; // Fully controlled by the FSM; no prefetch to avoid conflicts
                end else if (in_cmd[9:8] == 2'b11) begin
                    calc_state <= C_MP_REQ;
                    mem0_addr_reg <= {in_cmd[7:4], 8'd0}; // Pre-fetch T1[0]
                end
            end else begin
                calc_state <= C_IDLE;
            end
        end 
        else if (state == S_CALC) begin
            case(calc_state)
                // ----------------------------------------------------
                // Opcode 00 & 01: Average & Subtraction Pipeline
                // ----------------------------------------------------
                C_AS_REQ1: begin
                    mem0_addr_reg <= tgt2_offset + pipe_cnt; 
                    if (pipe_cnt > 0) begin
                        if (opcode == 2'b00) 
                            out_buf[pipe_cnt - 9'd1] <= ({1'b0, tgt1_img} + {1'b0, mem0_dout}) >> 1;
                        else 
                            out_buf[pipe_cnt - 9'd1] <= (tgt1_img > mem0_dout) ? (tgt1_img - mem0_dout) : (mem0_dout - tgt1_img);
                    end
                    if (pipe_cnt == 256) calc_state <= C_DONE;
                    else                 calc_state <= C_AS_REQ2;
                end
                
                C_AS_REQ2: begin
                    mem0_addr_reg <= tgt1_offset + pipe_cnt + 1; 
                    tgt1_img <= mem0_dout; 
                    pipe_cnt <= pipe_cnt + 1;
                    calc_state <= C_AS_REQ1;
                end

                // ----------------------------------------------------
                // Opcode 10: Swap Pipeline (5-State Safe Loop)
                // ----------------------------------------------------
                C_SW_RD_T1: begin
                    mem0_addr_reg <= tgt1_offset + pipe_cnt;
                    mem0_web_reg <= 1; 
                    calc_state <= C_SW_RD_T2;
                end
                
                C_SW_RD_T2: begin
                    mem0_addr_reg <= tgt2_offset + pipe_cnt;
                    mem0_web_reg <= 1; 
                    calc_state <= C_SW_WAIT_T1;
                end
                
                C_SW_WAIT_T1: begin
                    tgt1_img <= mem0_dout; // Get T1
                    calc_state <= C_SW_WAIT_T2;
                end
                
                C_SW_WAIT_T2: begin
                    tgt2_img <= mem0_dout; // Get T2
                    
                    // Prepare to overwrite T1 (write the newly read T2 into T1 address)
                    mem0_addr_reg <= tgt1_offset + pipe_cnt;
                    mem0_din_reg <= mem0_dout; 
                    mem0_web_reg <= 0; 
                    
                    sum1 <= sum1 + tgt1_img;
                    sum2 <= sum2 + mem0_dout;
                    calc_state <= C_SW_WR_T2;
                end
                
                C_SW_WR_T2: begin
                    // Prepare to overwrite T2 (write previously read T1 into T2 address)
                    mem0_addr_reg <= tgt2_offset + pipe_cnt;
                    mem0_din_reg <= tgt1_img; 
                    mem0_web_reg <= 0; 
                    
                    if (pipe_cnt == 255) begin
                        calc_state <= C_SW_WIN_WAIT1;
                    end else begin
                        pipe_cnt <= pipe_cnt + 1;
                        calc_state <= C_SW_RD_T1; // Loop back cleanly, no override!
                    end
                end
                
                C_SW_WIN_WAIT1: begin
                    mem0_web_reg <= 1; // STOP writing
                    // The images have been swapped; original T1 (sum1) is now at tgt2_offset.
                    mem0_addr_reg <= (sum1 > sum2 ? tgt2_offset : tgt1_offset); 
                    pipe_cnt <= 0;
                    calc_state <= C_SW_WIN_REQ;
                end
                
                C_SW_WIN_REQ: begin
                    mem0_addr_reg <= (sum1 > sum2 ? tgt2_offset : tgt1_offset) + pipe_cnt + 1;
                    if (pipe_cnt > 0) out_buf[pipe_cnt - 9'd1] <= mem0_dout;
                    
                    if (pipe_cnt == 256) calc_state <= C_DONE;
                    else                 pipe_cnt <= pipe_cnt + 1;
                end

                // ----------------------------------------------------
                // Opcode 11: Maxpool Pipeline
                // ----------------------------------------------------
                C_MP_REQ: begin
                    mem0_addr_reg <= tgt1_offset + pipe_cnt + 1; 
                    if (pipe_cnt > 0) begin
                        if (pipe_cnt[3:0] == 4'd1) begin
                            mp_max <= mem0_dout; 
                        end else begin
                            mp_max <= (mem0_dout > mp_max) ? mem0_dout : mp_max;
                        end

                        if (pipe_cnt[3:0] == 4'd0) begin
                            for (i = 0; i < 16; i = i + 1) begin
                                out_buf[pipe_cnt - 9'd16 + i] <= (mem0_dout > mp_max) ? mem0_dout : mp_max;
                            end
                        end
                    end
                    
                    if (pipe_cnt == 256) calc_state <= C_DONE;
                    else                 pipe_cnt <= pipe_cnt + 1;
                end
                
                default: calc_state <= C_IDLE;
            endcase
        end
    end
end

// 6. Output Stage Control
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_cnt <= 0;
        out_valid <= 0;
        out_data <= 0;
    end else if (state == S_OUT) begin
        out_valid <= 1;
        out_data  <= out_buf[out_cnt[7:0]];
        out_cnt   <= out_cnt + 1;
    end else begin
        out_cnt <= 0;
        out_valid <= 0;
        out_data <= 0;
    end
end

//==================================================================
// SRAM Connections (Do not modify the names below per TA's spec)
//==================================================================
assign mem0_addr = mem0_addr_reg;
assign mem0_din  = mem0_din_reg;
assign mem0_web  = mem0_web_reg;




//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 
  There are eight SRAMs in your GTE. You should not change the name of those SRAMs.
  TA will check the value in each SRAMs when your GTE is not busy.
  If you change the name of SRAMs below, you must get the fail in this lab.
  
  You should finish SRAM-related signals assignments for each SRAM.
*/
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


// MEM_0, MEM_1, MEM_2, MEM_3, MEM_4, MEM_5, MEM_6, MEM_7 instantiation
SUMA180_4096X8X1BM4 MEM0(
    .A0(mem0_addr[0]), .A1(mem0_addr[1]), .A2(mem0_addr[2]), .A3(mem0_addr[3]), .A4(mem0_addr[4]), .A5(mem0_addr[5]), .A6(mem0_addr[6]), .A7(mem0_addr[7]), 
    .A8(mem0_addr[8]), .A9(mem0_addr[9]), .A10(mem0_addr[10]), .A11(mem0_addr[11]),
    .DO0(mem0_dout[0]), .DO1(mem0_dout[1]), .DO2(mem0_dout[2]), .DO3(mem0_dout[3]), .DO4(mem0_dout[4]), .DO5(mem0_dout[5]), .DO6(mem0_dout[6]), .DO7(mem0_dout[7]),
    .DI0(mem0_din[0]), .DI1(mem0_din[1]), .DI2(mem0_din[2]), .DI3(mem0_din[3]), .DI4(mem0_din[4]), .DI5(mem0_din[5]), .DI6(mem0_din[6]), .DI7(mem0_din[7]),
    .CK(clk), .WEB(mem0_web), .OE(1'b1), .CS(1'b1)
);
endmodule