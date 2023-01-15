`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/11/22 10:23:13
// Design Name: 
// Module Name: hazard
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hazard(
	//fetch stage
	output wire stallF,
	output wire flushF,
	//decode stage
	input wire[4:0] rsD,rtD,
	input wire[4:0] rdE,rdM,
	input wire branchD,jumprD,
	input wire predict_wrong,
	output wire forwardaD,forwardbD,
	output wire stallD,
	output wire flushD,
	//execute stage
	// input wire stall_divE,
	input wire[4:0] rsE,rtE,
	input wire[4:0] writeregE,
	input wire branchE,
	input wire regwrite_enE,
	input wire[1:0] memtoregE,
	input wire div_stallE,
	input wire cp0_writeM,
	output wire[1:0] forwardaE,forwardbE,
	output wire flushE,stallE,
	output wire forwardcp0E,
	//mem stage
	input wire[4:0] writeregM,
	input wire regwrite_enM,
	input wire[1:0] memtoregM,
	output wire stallM,
	output wire flushM,
	//write back stage
	input wire[4:0] writeregW,
	input wire regwrite_enW,
	output wire stallW,
	output wire flushW,

	input wire al_instW,al_instM,
    input wire i_stall,       // 两个访存 stall信号
    input wire d_stall,
	output wire all_stall, // 全局stall指令
	input wire exception_en
    );

	wire lwstallD,branchstallD,jrstall;

	//forwarding sources to D stage (branch equality)
	assign forwardaD = (rsD != 5'b0 & (rsD == writeregM) & regwrite_enM);
	assign forwardbD = (rtD != 5'b0 & (rtD == writeregM) & regwrite_enM);
	
	//forwarding sources to E stage (ALU)
	assign forwardaE = ((rsE != 5'b0) && regwrite_enM && (rsE == writeregM)) ? 2'b10 :
					   ((rsE != 5'b0) && regwrite_enW && (rsE == writeregW)) ? 2'b01 : 2'b00;
					   
	assign forwardbE = ((rtE != 5'b0) && regwrite_enM && (rtE == writeregM)) ? 2'b10 :
					   ((rtE != 5'b0) && regwrite_enW && (rtE == writeregW)) ? 2'b01 : 2'b00;

    // mtc0 mfc0冲突
	assign forwardcp0E = (rdE && (rdE == rdM) && cp0_writeM);

  	//stalls
	assign lwstallD = memtoregE & (rtE == rsD | rtE == rtD);
	assign branchstallD = branchD &
				(regwrite_enE & (writeregE != 5'b00000) &
				(writeregE == rsD | writeregE == rtD) |
				memtoregM & (writeregM != 5'b00000) &
				(writeregM == rsD | writeregM == rtD));
	assign jrstall = jumprD & regwrite_enE & ((writeregE == rsD) | (writeregE == rtD)); //|
	
	assign all_stall = div_stallE | i_stall | d_stall;
    assign stallF = (lwstallD | jrstall | branchstallD | all_stall) & ~exception_en;
    assign stallD = lwstallD | jrstall | branchstallD | all_stall;
    assign stallE = all_stall;
    assign stallM = all_stall;
	assign stallW = (al_instW & ~al_instM)|all_stall;

    assign flushF = 1'b0;
    // assign flushD = ((branchE & predict_wrong) | exceptionoccur) & (~all_stall);
//	assign flushD = ((branchE & predict_wrong) | exception_en) & ~all_stall;
    assign flushD = exception_en & ~all_stall;
    assign flushE = (lwstallD | jrstall | exception_en) & ~all_stall; // TODO:exceptionoccur信号用于异常时清除所有的寄存器，还未完全测试
    assign flushM = exception_en & ~all_stall;
    assign flushW = exception_en & ~all_stall;
endmodule
