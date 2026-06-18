//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2026 Spring
//   lab08 Exercise		
//   Author     		: Cho-Hsun Lee 
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

`define CYCLE_TIME      15.0
`define SEED_NUMBER     69
`define PATTERN_NUMBER  100

module PATTERN(
    // Output Port
    clk,
    rst_n,
    in_valid,
    in_data,

    // Input Port
    out_valid,
    out_data
    );

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output  logic        clk, rst_n, in_valid;
output  logic[7:0]  in_data;

input           out_valid;
input   [11:0]   out_data;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
real CYCLE = `CYCLE_TIME;
real seed = `SEED_NUMBER;







endmodule



