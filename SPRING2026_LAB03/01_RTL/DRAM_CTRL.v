module DRAM_CTRL (
    input               clk,
    input               rst_n,
    
    // AXI4-Lite slave interface
    input [31:0]        aw_addr,
    input               aw_valid,
    output reg          aw_ready,
    input [63:0]        w_data,
    input               w_valid,
    output reg          w_ready,
    output wire [1:0]   b_resp,
    output wire         b_valid,
    input               b_ready,
    
    input [31:0]        ar_addr,
    input               ar_valid,
    output reg          ar_ready,
    output reg [63:0]   r_data,
    output wire [1:0]   r_resp,
    output wire         r_valid,
    input               r_ready,

    // DRAM master interface
    output reg  [3:0]   dram_cmd,  // {CS_n, RAS_n, CAS_n, WE_n}
    output reg  [1:0]   dram_ba,
    output reg  [10:0]  dram_addr,
    output reg  [63:0]  dram_wdata,
    input [63:0]        dram_rdata,
    input               dram_valid
);

    
endmodule