`include "defines.vh"
module write_data(
    input wire [7:0] alucontrolE,	//ALU控制信号
	input wire [31:0] aluoutE,		//ALU运算结果（待写入的地址）
	input wire [31:0] WriteDataE,	//待写入数据
	output reg [3:0] sig_writeE,	//写使能信号
	output wire[31:0] WriteDataE_modified,	//处理后的写入数据
	output reg sig_enE	//d_ram使能信号
    );
    // 为sig_enE、sig_write信号赋值
    always @ (*) 
	begin
		case (alucontrolE)
			`EXE_LW_OP,`EXE_LB_OP,`EXE_LBU_OP,`EXE_LH_OP,`EXE_LHU_OP:
            // load指令 使能信号=1，写使能=0000
			begin
                sig_writeE <= 4'b0000;
				sig_enE <= 1;
			end
			`EXE_SW_OP:
            // SW 使能=1，写使能=1111
			begin 
				case (aluoutE[1:0])
					2'b00: sig_writeE <= 4'b1111;
					// 地址有误
					default: sig_writeE <= 4'b0000;
				endcase
				sig_enE <= 1;
			end

			`EXE_SH_OP:
            // SH 使能=1，写使能=1100/0011
			begin
				case (aluoutE[1:0])
					//根据地址末尾两位判断写入的位置
					2'b10: sig_writeE <= 4'b1100;
					2'b00: sig_writeE <= 4'b0011;
					// 地址有误
					default: sig_writeE <= 4'b0000;
				endcase
				sig_enE <= 1;
			end

			`EXE_SB_OP:
            // SB 使能=1，写使能=1000/0100/0010/0001
			begin
				case (aluoutE[1:0])
					//根据地址末尾两位判断写入的位置
					2'b11: sig_writeE <= 4'b1000;
					2'b10: sig_writeE <= 4'b0100;
					2'b01: sig_writeE <= 4'b0010;
					2'b00: sig_writeE <= 4'b0001;
				endcase
				sig_enE <= 1;
			end
			// 其他无关指令 使能=0，写使能=0000
			default: 
			begin
				sig_writeE <= 4'b0000;
				sig_enE <= 0;
			end
		endcase
	end

	// 为修改后的待写入数据赋值
    assign WriteDataE_modified = (sig_writeE ==  4'b0000 || sig_writeE ==  4'b1111)?WriteDataE: //字操作/无关操作无需处理
                                (sig_writeE ==  4'b1100 || sig_writeE ==  4'b0011)? {2{WriteDataE[15:0]}} : //半字操作，直接复制半字
                                {4{WriteDataE[7:0]}} ;  //字节操作，复制该字节

endmodule