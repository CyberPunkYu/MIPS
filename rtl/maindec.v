`timescale 1ns / 1ps

`include "defines.vh"
module maindec(
	input wire [5:0] op,
	input wire [4:0] rs,rt,
	input wire [5:0] funct,

	output wire [1:0] memtoreg, //00->aluresult 01->readdata 10->hi 11->lo
	output wire memwrite,   // en signal
	output wire branch,     
    output wire alusrc,     // 0 -> reg, 1 -> imm 
    output wire regdst,    // 1->rd 0->rt
    output wire regwrite,   // en signal 
	output wire gprtohi,   //gprtohi GPR->hi
	output wire gprtolo,   //gprtolo GPR->lo
    
    output reg al_instD,
    output wire write_al,
	output wire jump,jumpr,     // 闂侀潻闄勫妯侯焽閸嶇椃mp闂佸憡绮岄懟顖炴儊鎼达綇鎷峰☉娅亜鈻嶉幒锟�??纾圭紒顖滅毇mp
    output reg riD,
    output reg cp0write // whether write to the cp0 or not
    );
    wire alinst;
	reg [8:0] main_signal;
    //闂佽法鍠愰弸濠氬箯閻戣姤鏅搁柡鍌橈拷?锟斤拷?锟界ilowrite闂佽法鍠曢崜濂告偖鐎涙ê锟�??
	// assign sign_ext = |(op[5:2] ^ 4'b0011);		//andi, xori, lui, ori???????????????
    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,gprtohi,gprtolo} = main_signal;
    // 闂佽法鍠愰弸濠氬箯閻戣姤鏅搁柡鍌橈拷?锟斤拷?锟界ump闂佽法鍠曢崜濂告偖鐎涙ê锟�??
    assign jump = ((op == `EXE_J) || (op == `EXE_JAL)) ? 1 : 0;
    assign jumpr = ((op == `EXE_NOP) && ((funct == `EXE_JR) || (funct == `EXE_JALR))) ? 1 : 0;

    assign write_al = (((op == `EXE_REGIMM_INST) && (rt == `EXE_BLTZAL || rt == `EXE_BGEZAL)) // 闂佽法鍠愰弸濠氬箯閻戣姤鏅搁柡鍌橈拷?锟斤拷?锟界zal闁圭ǹ娲弫鎾诲棘閵堝棗锟�??
                        || (op == `EXE_JAL)) ? 1 : 0;  // jal闁圭ǹ娲弫鎾诲棘閵堝棗锟�??
    
    
    always @(*) begin
        al_instD <= 0;
        cp0write = 0;
        riD = 0;
		case(op)
			`EXE_NOP:
			case(funct)
				// logic instr
				`EXE_AND, `EXE_OR, `EXE_XOR, `EXE_NOR, 
			    `EXE_SLL, `EXE_SRL, `EXE_SRA, `EXE_SLLV, `EXE_SRLV, `EXE_SRAV,
                `EXE_ADD, `EXE_ADDU, `EXE_SUB, `EXE_SUBU, `EXE_SLT, `EXE_SLTU: main_signal <= 9'b11000_00_00; // R-type
                
                `EXE_MULT, `EXE_MULTU, `EXE_DIV, `EXE_DIVU: main_signal <= 9'b11000_00_11;
                
                `EXE_MFHI: main_signal <= 9'b11000_10_00;//  hi -> gpr
                `EXE_MFLO: main_signal <= 9'b11000_11_00;//  lo -> gpr
                `EXE_MTHI: main_signal <= 9'b00000_00_10;
                `EXE_MTLO: main_signal <= 9'b00000_00_01;
                
                `EXE_SYSCALL,`EXE_BREAK : main_signal <= 9'b00000_00_00;
                

                // j inst
                `EXE_JR:  main_signal <= 9'b00000_00_00;
                `EXE_JALR:begin
                    main_signal <= 9'b11000_00_00;  // 闁???锟絩d娴ｆ粈璐熼崘娆忕槑鐎涙ê娅掓担宥囷拷???
                    al_instD <= 1'b1;
                end

                default:begin
                    main_signal <= 9'b00000_00_00;
                    riD = 1;
                end 
			endcase
			// logic inst
            `EXE_ANDI ,`EXE_XORI, `EXE_LUI, `EXE_ORI: main_signal <= 9'b10100_00_00; // Immediate
            
            `EXE_ADDI, `EXE_ADDIU ,`EXE_SLTI, `EXE_SLTIU: main_signal <= 9'b10100_00_00; // Immediate
            
            // branch inst
            `EXE_BEQ, `EXE_BGTZ, `EXE_BLEZ, `EXE_BNE    :main_signal <= 9'b00010_00_00    ;
            
            `EXE_REGIMM_INST: case(rt)
                `EXE_BLTZ   :main_signal <= 9'b00110_00_00      ;
                `EXE_BLTZAL :begin
                    main_signal <= 9'b10110_00_00;
                    al_instD <= 1'b1;
                end
                `EXE_BGEZ   :main_signal <= 9'b00110_00_00      ;
                `EXE_BGEZAL :begin
                    main_signal <= 9'b10110_00_00;
                    al_instD <= 1'b1;
                end
                default: riD = 1;
            endcase
            
            // j inst
            `EXE_J  : main_signal <= 9'b00000_00_00;
            `EXE_JAL: begin
                main_signal <= 9'b10000_00_00;
                al_instD <= 1'b1;
            end

            // memory insts
            `EXE_LB : main_signal <= 9'b10101_01_00;
            `EXE_LBU: main_signal <= 9'b10101_01_00;
            `EXE_LH : main_signal <= 9'b10101_01_00;
            `EXE_LHU: main_signal <= 9'b10101_01_00;
            `EXE_LW : main_signal <= 9'b10101_01_00;  // lab4 lw
            `EXE_SB : main_signal <= 9'b00101_00_00;  
            `EXE_SH : main_signal <= 9'b00101_00_00;  
            `EXE_SW : main_signal <= 9'b00101_00_00;  // lab4 sw

            // 閻楄娼堥幐鍥︼拷???
            6'b010000 : case(rs)
                5'b00100:begin  // mtc0
                    cp0write = 1;
                    main_signal <= 9'b00000_00_00;
                end 
                5'b00000: main_signal <= 9'b10000_00_00; // mfc0
                5'b10000: main_signal <= 9'b00000_00_00; // eret TODO: 閸欏偊锟�??????閿熸垝鍞惍浣疯厬regwrite閿燂拷???????1閿涘矁绻栭柌灞肩瑝閿燂拷????1
                default: begin
                    riD = 1;
                    main_signal <= 9'b00000_00_00;  // error op
                end 
            endcase

            default:begin
                riD = 1;
                main_signal <= 9'b00000_00_00;  // error op
            end 
		endcase
	end
endmodule
