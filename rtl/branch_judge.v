`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/01/02 15:45:30
// Design Name: 
// Module Name: branch_judge
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


// module branch_judge(
//     input wire[7:0]branch_judge_controlE,
//     input wire[31:0]srcaE,srcbE,
//     output wire branch_takeE     // �Ƿ���ת
//     );
    
//     assign branch_takeE = (branch_judge_controlE == `EXE_BEQ_OP) ? (srcaE == srcbE):               // == 0
//                   (branch_judge_controlE == `EXE_BNE_OP) ? (srcaE != srcbE):                       // != 0
//                   (branch_judge_controlE == `EXE_BGTZ_OP) ? ((srcaE[31]==1'b0) && (srcaE!=32'b0)): // > 0 
//                   (branch_judge_controlE == `EXE_BLEZ_OP) ? ((srcaE[31]==1'b1) || (srcaE==32'b0)): // <= 0
//                   (branch_judge_controlE == `EXE_BLTZ_OP) ? (srcaE[31] == 1'b1):                  // < 0
//                   (branch_judge_controlE == `EXE_BGEZ_OP) ? (srcaE[31] == 1'b0):                  // >= 0
//                   // ��������������ָ�� �����Ƿ���ת ����дGHR[31]
//                   (branch_judge_controlE == `EXE_BLTZAL_OP) ? (srcaE[31] == 1'b1):                // < 0
//                   (branch_judge_controlE == `EXE_BGEZAL_OP) ? (srcaE[31] == 1'b0):                // >= 0
//                   (1'b0);
// endmodule
module branch_judge(
    input wire[7:0]branch_judge_controlD,
    input wire[31:0]srca2D,srcb2D,
    output wire branch_takeD     // �Ƿ���ת
    );
    
    assign branch_takeD = (branch_judge_controlD == `EXE_BEQ_OP) ? (srca2D == srcb2D):               // == 0
                  (branch_judge_controlD == `EXE_BNE_OP) ? (srca2D != srcb2D):                       // != 0
                  (branch_judge_controlD == `EXE_BGTZ_OP) ? ((srca2D[31]==1'b0) && (srca2D!=32'b0)): // > 0 
                  (branch_judge_controlD == `EXE_BLEZ_OP) ? ((srca2D[31]==1'b1) || (srca2D==32'b0)): // <= 0
                  (branch_judge_controlD == `EXE_BLTZ_OP) ? (srca2D[31] == 1'b1):                  // < 0
                  (branch_judge_controlD == `EXE_BGEZ_OP) ? (srca2D[31] == 1'b0):                  // >= 0
                  // ��������������ָ�� �����Ƿ���ת ����дGHR[31]
                  (branch_judge_controlD == `EXE_BLTZAL_OP) ? (srca2D[31] == 1'b1):                // < 0
                  (branch_judge_controlD == `EXE_BGEZAL_OP) ? (srca2D[31] == 1'b0):                // >= 0
                  (1'b0);
endmodule
