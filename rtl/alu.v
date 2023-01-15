`timescale 1ns / 1ps
`include "defines.vh"

module alu(
	input  wire			clk,
	input  wire			rst,
	input  wire [31:0] 	alu_num1,alu_num2,
	input  wire [7:0] 	alucontrol,
	input  wire [63:0] 	hilo, 
	input  wire [4:0] 	sa,
	input  wire  		flushE,
	input  wire  		stallM,
    input  wire [31:0]  pcplus4E,
	input  wire [31:0]  cp0toalu,
	output wire [31:0] 	alu_out,
	output reg  [63:0] 	alu_out_64,
	output wire 		overflowE,
	output wire 		div_stallE,
	output wire  		res_validE,
	output wire 		addressErrL,
	output wire  		addressErrS

    );
	reg [31:0] alu_ans;
    reg [31:0] num2_reg;


	// overflow check
    wire overflow_add;
    wire overflow_sub;
    assign overflow_add = ( (alu_ans[31] & (~alu_num1[31] & ~alu_num2[31])) 
                || (~alu_ans[31] & (alu_num1[31] & alu_num2[31]))) &&(alucontrol == `EXE_ADD_OP || alucontrol == `EXE_ADDI_OP );
    assign overflow_sub = ( (alucontrol == `EXE_SUB_OP ) && 
                ((alu_ans[31] & (~alu_num1[31] & ~num2_reg[31])) || (~alu_ans[31] & (alu_num1[31] & num2_reg[31]))) 
                );
    assign overflowE = overflow_add || overflow_sub;

	// addressError
    assign addressErrL = ( (alucontrol == `EXE_LH_OP || alucontrol == `EXE_LHU_OP) && (alu_ans[0] != 0) )? 1:
                            (alucontrol == `EXE_LW_OP && alu_ans[1:0] != 2'b00)? 1: 0;
    assign addressErrS = ( (alucontrol == `EXE_SH_OP) && (alu_ans[0] != 0) )? 1:
                            (alucontrol == `EXE_SW_OP && alu_ans[1:0] != 2'b00)? 1: 0;

    //////////////////////////// div ///////////////////////////
    wire [63:0] div_result;
    wire div_sign;
	wire div_valid;
	wire div_res_validE;
	wire mul_res_validE;
	wire div_res_ready;
	assign mul_res_validE= (alucontrol == `EXE_MULT_OP) || (alucontrol == `EXE_MULTU_OP);
	assign res_validE    = div_res_validE | mul_res_validE;
	assign div_sign      = (alucontrol == `EXE_DIV_OP);
	assign div_valid     = (alucontrol == `EXE_DIV_OP) || (alucontrol == `EXE_DIVU_OP);
	assign div_res_ready = div_valid & ~stallM;
	assign div_stallE    = div_valid & ~div_res_validE;

	div div(
		.clk(clk),
		.rst(rst | flushE),
		.a(alu_num1), 
		.b(alu_num2),
		.sign(div_sign), 

		.opn_valid(div_valid), 
        .res_ready(div_res_ready), 
        .res_valid(div_res_validE), 
		.result(div_result) 
	);

	///////////////////////// div end //////////////////////////
	always @(*) begin
		num2_reg = 0;
		case(alucontrol)

			`EXE_AND_OP	:	alu_ans = alu_num1 & alu_num2;
			`EXE_OR_OP	:	alu_ans = alu_num1 | alu_num2;
			`EXE_XOR_OP	:	alu_ans = alu_num1 ^ alu_num2;
			`EXE_NOR_OP	:	alu_ans = ~(alu_num1 | alu_num2);
			
			`EXE_ANDI_OP:	alu_ans = alu_num1 & {{16{1'b0}}, alu_num2[15:0]};
			`EXE_ORI_OP:	alu_ans = alu_num1 | {{16{1'b0}}, alu_num2[15:0]};
			`EXE_XORI_OP:	alu_ans = alu_num1 ^ {{16{1'b0}}, alu_num2[15:0]};
			`EXE_LUI_OP:	alu_ans = {alu_num2[15:0], {16{1'b0}}};

			`EXE_SLL_OP: 	alu_ans = alu_num2 << sa;
			`EXE_SRL_OP: 	alu_ans = alu_num2 >> sa;
			`EXE_SRA_OP: 	alu_ans = $signed(alu_num2) >>> sa;
			`EXE_SLLV_OP: 	alu_ans = alu_num2 << alu_num1[4:0];
			`EXE_SRLV_OP: 	alu_ans = alu_num2 >> alu_num1[4:0];
			`EXE_SRAV_OP: 	alu_ans = $signed(alu_num2) >>> alu_num1[4:0];
			
			`EXE_MFHI_OP:	alu_ans    = hilo[63:32];
			`EXE_MFLO_OP:	alu_ans    = hilo[31:0];
			`EXE_MTHI_OP:	alu_out_64 = {alu_num1, hilo[31:0]};
			`EXE_MTLO_OP:	alu_out_64 = {hilo[63:32],alu_num1};

			`EXE_ADD_OP:	alu_ans = alu_num1 + alu_num2;
			`EXE_ADDU_OP:	alu_ans = alu_num1 + alu_num2;

			`EXE_SUB_OP:
				begin
				num2_reg = -alu_num2;
				alu_ans = alu_num1 + num2_reg;
				end
			`EXE_SUBU_OP:	alu_ans = alu_num1 - alu_num2;
			`EXE_SLT_OP:	alu_ans = $signed(alu_num1) < $signed(alu_num2);
			`EXE_SLTU_OP:	alu_ans = alu_num1 < alu_num2;
            `EXE_ADDI_OP:	alu_ans = alu_num1 + alu_num2;
            `EXE_ADDIU_OP:	alu_ans = alu_num1 + alu_num2;
            `EXE_SLTI_OP:	alu_ans = $signed(alu_num1) < $signed(alu_num2);
            `EXE_SLTIU_OP:	alu_ans = alu_num1 < alu_num2;
			
			`EXE_MULTU_OP:  alu_out_64 = {32'b0, alu_num1} * {32'b0, alu_num2};
            `EXE_MULT_OP:   alu_out_64 = $signed(alu_num1) * $signed(alu_num2);

			`EXE_DIV_OP:	alu_out_64 = div_result;
			`EXE_DIVU_OP:   alu_out_64 = div_result;

			`EXE_J_OP:		alu_ans = alu_num1 + alu_num2;
			`EXE_JR_OP:		alu_ans = alu_num1 + alu_num2;
			`EXE_JAL_OP:	alu_ans = pcplus4E + 32'h4;
			`EXE_JALR_OP:	alu_ans = pcplus4E + 32'h4;
			 
            `EXE_BEQ_OP:	alu_ans = alu_num1 - alu_num2;
            `EXE_BNE_OP:	alu_ans = alu_num1 - alu_num2;
            `EXE_BLTZAL_OP:	alu_ans = pcplus4E + 32'h4  ;
            `EXE_BGEZAL_OP:	alu_ans = pcplus4E + 32'h4  ;

            `EXE_LB_OP:		alu_ans = alu_num1 + alu_num2;
            `EXE_LBU_OP:	alu_ans = alu_num1 + alu_num2;
            `EXE_LH_OP:		alu_ans = alu_num1 + alu_num2;
            `EXE_LHU_OP:	alu_ans = alu_num1 + alu_num2;
            `EXE_LW_OP:		alu_ans = alu_num1 + alu_num2;
            `EXE_SB_OP:		alu_ans = alu_num1 + alu_num2;
            `EXE_SH_OP:		alu_ans = alu_num1 + alu_num2;
            `EXE_SW_OP:		alu_ans = alu_num1 + alu_num2;

            `EXE_MTC0_OP : alu_ans <= alu_num2      ;
            `EXE_MFC0_OP : alu_ans <= cp0toalu  ;
            `EXE_ERET_OP : alu_ans <= 32'b0     ;
            default: begin
				alu_ans = 32'b0;
				alu_out_64 = 64'b0;
			end
	endcase
	end
	assign alu_out = (overflowE == 1) ? 0:alu_ans;

endmodule