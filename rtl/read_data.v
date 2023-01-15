`include "defines.vh"
module read_data(
	input wire [7:0] alucontrolW,	//alu控制信号
	input wire [31:0] readdataW,	//读出的数据
    input wire [31:0] dataadrW,		//数据来源地址
	output reg[31:0] readdataW_modified	//处理后的读出数据
    );
    
	// 根据指令读取对应数据
    always @ (*)
	begin
		case (alucontrolW)
			`EXE_LW_OP:
			// LW指令 无需修改数据
                readdataW_modified <= readdataW;

			`EXE_LH_OP:
			// LH指令 根据地址低两位判断，作符号拓展
			begin 
				case (dataadrW[1:0])
					2'b10: readdataW_modified <= {{16{readdataW[31]}},readdataW[31:16]};
					2'b00: readdataW_modified <= {{16{readdataW[15]}},readdataW[15:0]};
					default: readdataW_modified <= readdataW;
				endcase
			end

			`EXE_LHU_OP:
			// LHU指令 根据地址低两位判断，作无符号拓展
			begin 
				case (dataadrW[1:0])
					2'b10: readdataW_modified <= {{16{1'b0}},readdataW[31:16]};
					2'b00: readdataW_modified <= {{16{1'b0}},readdataW[15:0]};
					default: readdataW_modified <= readdataW;
				endcase
			end

			`EXE_LB_OP:
			// LB指令 根据地址低两位判断，作符号拓展
			begin 
				case (dataadrW[1:0])
					2'b11: readdataW_modified <= {{24{readdataW[31]}},readdataW[31:24]};
					2'b10: readdataW_modified <= {{24{readdataW[23]}},readdataW[23:16]};
					2'b01: readdataW_modified <= {{24{readdataW[15]}},readdataW[15:8]};
					2'b00: readdataW_modified <= {{24{readdataW[7]}},readdataW[7:0]};
                    default: readdataW_modified <= readdataW;	        
				endcase
			end

			`EXE_LBU_OP:
			// LBU指令 根据地址低两位判断，作无符号拓展
			begin 
				case (dataadrW[1:0])
					2'b11: readdataW_modified <= {{24{1'b0}},readdataW[31:24]};
					2'b10: readdataW_modified <= {{24{1'b0}},readdataW[23:16]};
					2'b01: readdataW_modified <= {{24{1'b0}},readdataW[15:8]};
					2'b00: readdataW_modified <= {{24{1'b0}},readdataW[7:0]};
                    default: readdataW_modified <= readdataW;
				endcase
			end
		endcase
	end

endmodule