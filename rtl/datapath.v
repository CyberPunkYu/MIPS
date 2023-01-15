`timescale 1ns / 1ps

module datapath(
	input wire clk,rst,
	input wire [5:0] int,
	output wire inst_en,
	output wire[31:0] pcF,
	input wire[31:0] instrF,
	output wire[3:0] sig_writeM,
	output wire[31:0] aluoutM,writedataM,
	input wire[31:0] readdataM,
	output wire sig_enM,
    output wire all_stall, 
    input wire i_stall,       
    input wire d_stall,

	output wire [31:0]  debug_wb_pc,      
    output wire [3:0]   debug_wb_rf_wen,
    output wire [4:0]   debug_wb_rf_wnum, 
    output wire [31:0]  debug_wb_rf_wdata
    );
	

	//decode stage
	wire regdstD;
	wire memwriteD,alusrcD,regwrite_enD,gprtohiD,gprtoloD;
	//execute stage
	wire memwriteE,gprtohiE,gprtoloE;
	wire gprtohiM,gprtoloM;

	wire regdstE;
	wire alusrcE,pcsrcD;
	wire [1:0] memtoregD,memtoregE,memtoregM,memtoregW;
	wire [63:0] hilo;
 	//FD
	wire [31:0] pcD,pcE,pcM,pcW,pcplus4F,pcplus4D,pcplus4E,pcnextbrFD,pcbranchD,pcbranchE,pcbranchM,pcnextFD,pcjumpD,pc_takeF;
	wire pc_reg_ceF;
	wire jump_conflictD;
	//decode stage
	wire jumpD,jumprD;
	wire [7:0] alucontrolD;

    wire [7:0] branch_judge_controlD;
	wire [31:0] instrD;
	wire forwardaD,forwardbD;
	wire [5:0] opD,functD;
	wire [4:0] rsD,rtD,rdD,saD;
	wire [31:0] signimmD,signimmshD;
	wire [31:0] srcaD,srca2D,srcbD,srcb2D;
	//execute stage
	wire[3:0] sig_writeE;
	wire sig_enE;
	wire div_stallE;
	wire [7:0] alucontrolE;
	wire [1:0] forwardaE,forwardbE;
	wire forwardcp0E;
	wire [4:0] rsE,rtE,rdE,saE;
	wire [4:0] writeregE;
	wire [4:0] writeregE_temp;
	wire [31:0] signimmE;
	wire [31:0] srcaE,srca2E,srcbE,srcb2E,srcb3E;
	wire [31:0] aluoutE;
	wire [63:0] aluout64E;
	wire [7:0] branch_judge_controlE;
	wire [31:0] WriteDataE_modified;
	wire regwrite_enE;
	wire res_validE;
	//mem stage
	wire [4:0] rdM;
	wire [4:0] writeregM;
	wire [31:0] hi_oM,lo_oM;
	wire [7:0] alucontrolM;
	wire regwrite_enM;

	//writeback stage
	wire [4:0] writeregW;
	wire [31:0] aluoutW,readdataW,resultW,hi_oW,lo_oW;
	wire [31:0] readdataW_modified;
    wire [7:0] alucontrolW;
    wire regwrite_enW;
	
	//hazard	
    wire stallF, stallD, stallE, stallM, stallW;
    wire flushF, flushD, flushE, flushM, flushW;

	//exception
	wire overflowE;
    wire addressErrL; 
    wire addressErrS; 
    //exception: pc??????,syscallD,breakD,eretD,riD,overflowE,addressErrl,addressErrs
    wire [7:0] exceptionF,exceptionD,exceptionE,exceptionM; // union exception control signal
	wire is_in_delayslotF,is_in_delayslotD,is_in_delayslotE,is_in_delayslotM;//CP0 delaysolt  
    wire riD;
    wire [31:0] exceptiontypeM;
    wire cp0writeD,cp0writeE,cp0_writeM;
    wire exception_en;
	wire [31:0] cp0_data_o;
	wire [31:0] cp0_status_o;
	wire [31:0] cp0_cause_o;
	wire [31:0] cp0_epc_o;
    wire [31:0] pcexceptionM;
    wire [31:0] cp0toalu;  // mfc0??lu??????
    wire [31:0]cp0_count_o,cp0_compare_o,cp0_config_o,cp0_prid_o,cp0_badvaddr,bad_addr;
    wire cp0_timer_int_o;
    wire [31:0] cause_o_revise,pcM_revise;
    reg [31:0] cause_o;
	wire syscallD, breakD, eretD;
    
    //predict
    wire branch_takeM, branch_takeE;
	wire branchD,branchE;

	wire [31:0] pc_temp1, pc_temp2, pc_temp3, pc_temp4;

    wire [4:0] pc_dst_al;
    wire write_alD,write_alE;
    assign pc_dst_al = 5'b11111;
	wire al_instD,al_instE,al_instM,al_instW;
	flopenrc #(1) 	al_instD2E(clk, rst, ~stallE, flushE, al_instD & stallD, al_instE);
	flopenrc #(1) 	al_instE2M(clk, rst, ~stallM, flushM, al_instE & forwardaD, al_instM);
	flopenrc #(1) 	al_instM2W(clk, rst, ~all_stall, flushW, al_instM, al_instW);

	// decoder
	maindec md(
		opD,rsD,rtD,functD,
		memtoregD,memwriteD,
		branchD,alusrcD,regdstD,regwrite_enD,
		gprtohiD,gprtoloD,al_instD,write_alD,jumpD,jumprD,
		riD,cp0writeD
		);
	aludec alu_decoder0(
		opD,rsD,rtD,functD,
		alucontrolD,branch_judge_controlD
    );


	//hazard detection
	hazard h(
		//fetch stage
		.stallF(stallF),
		.flushF(flushF),
		//decode stage
		.rsD(rsD),.rtD(rtD),
		.rdE(rdE),.rdM(rdM),
		.branchD(branchD),.jumprD(jumprD),
		.forwardaD(forwardaD),.forwardbD(forwardbD),
		.predict_wrong(predict_wrong),
		.stallD(stallD),
		.flushD(flushD),
		//execute stage
		.rsE(rsE),.rtE(rtE),
		.writeregE(writeregE),
		.regwrite_enE(regwrite_enE),
		.branchE(branchE),
		.memtoregE(memtoregE),
		.div_stallE(div_stallE),
		.cp0_writeM(cp0_writeM),
		.forwardaE(forwardaE),.forwardbE(forwardbE),
		.flushE(flushE),.stallE(stallE),
		.forwardcp0E(forwardcp0E),
		//mem stage
		.writeregM(writeregM),
		.regwrite_enM(regwrite_enM),
		.memtoregM(memtoregM),
		.flushM(flushM),
		.stallM(stallM),
		//write back stage
		.writeregW(writeregW),
		.regwrite_enW(regwrite_enW),
		.stallW(stallW),
		.flushW(flushW),

		.al_instW(al_instW),.al_instM(al_instM),
     	.i_stall(i_stall),
 		.d_stall(d_stall),
		.all_stall(all_stall),
		.exception_en(exception_en)
		);

	reg pre_inst_en;
	assign inst_en = pre_inst_en & ~exception_en;

	always @(negedge clk) begin
        if(rst) begin
            pre_inst_en <= 0;
        end
        else begin
            pre_inst_en <= 1;
        end
    end

	// pc branch
	wire branch_takeD;
	assign pcsrcD = branch_takeD;
	mux2 #(32) pcbrmux(pcplus4F,pcbranchD,pcsrcD,pcnextbrFD);
	// you can't delete the next code
	mux2 #(32) pcmux(pcnextbrFD,pcjumpD,jumpD | jumprD,pcnextFD);
	mux2 #(32) pcexceptionmux(pcnextFD,pcexceptionM,exception_en,pc_takeF);


    //remove stallW temporarily 
	//regfile (operates in decode and writeback)
	regfile regfile0(
		.clk(clk),
		.stallW(stallW),
		.we3(regwrite_enW),
		.ra1(rsD), 
		.ra2(rtD), 
		.wa3(writeregW), 
		.wd3(resultW),
		.rd1(srcaD), 
		.rd2(srcbD)
    );

	//fetch stage logic
	pc #(32) pcreg(clk,rst,~stallF,pc_takeF,pcF,pc_reg_ceF);
	adder pcadd1(pcF,32'b100,pcplus4F);

    assign exceptionF = (pcF[1:0] == 2'b00) ? 8'b00000000 : 8'b10000000;//pc don't match
	assign is_in_delayslotF = (jumpD|jumprD|branchD);

	//flop 2
	flopenrc #(32) fp2_1(clk,rst,~stallD,flushD,pcplus4F,pcplus4D);
	flopenrc #(32) fp2_2(clk,rst,~stallD,flushD,instrF,instrD);
	flopenrc #(32) fp2_3(clk,rst,~stallD,flushD,pcF,pcD);
    flopenrc #(8)  fp2_4(clk,rst,~stallD,flushD,exceptionF,exceptionD);
	flopenrc #(1)  fp2_5(clk, rst, ~stallD , flushD,is_in_delayslotF,is_in_delayslotD);

	// decode stage 
	signext se(instrD[15:0],signimmD);
	sl2 immsh(signimmD,signimmshD);
	adder pcadd2(pcplus4D,signimmshD,pcbranchD);
	mux2 #(32) forwardamux(srcaD,aluoutM,forwardaD,srca2D);
	mux2 #(32) forwardbmux(srcbD,aluoutM,forwardbD,srcb2D);

	assign opD = instrD[31:26];
	assign rsD = instrD[25:21];
	assign rtD = instrD[20:16];
	assign rdD = instrD[15:11];
	assign functD = instrD[5:0];
	assign saD = instrD[10:6];

    // exception judge
    assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
	assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
	assign eretD = (instrD == 32'b01000010000000000000000000011000);

    assign jump_conflictD = jumprD &&
                            ((regwrite_enE && rsD == writeregE) ||          
                            (regwrite_enM && rsD == writeregM));
    
    wire [31:0] pcjumpimmD;
    assign pcjumpimmD = {pcplus4D[31:28], instrD[25:0], 2'b00};
    assign pcjumpD = jumpD ?  pcjumpimmD : srca2D;

	// merge flopenrc
	flopenrc #(32)  fp3_2(clk, rst, ~stallE, flushE, pcbranchD, pcbranchE);
	flopenrc #(8)  	fp3_3(clk, rst, ~stallE, flushE, branch_judge_controlD, branch_judge_controlE);
	flopenrc #(32)  fp3_4(clk, rst, ~stallE, 1'b0, pcplus4D, pcplus4E);
	flopenrc #(32)  fp3_6(clk, rst, ~stallE, flushE, srca2D, srcaE);
	flopenrc #(32)  fp3_7(clk, rst, ~stallE, flushE, srcb2D, srcbE);
	flopenrc #(32)  fp3_8(clk, rst, ~stallE, flushE, signimmD, signimmE);
	flopenrc #(5)  	fp3_9(clk, rst, ~stallE, flushE, rsD, rsE);
	flopenrc #(5)  	fp3_10(clk, rst, ~stallE, flushE, rtD, rtE);
	flopenrc #(5)  	fp3_11(clk, rst, ~stallE, flushE, rdD, rdE);
	flopenrc #(5)  	fp3_22(clk, rst, ~stallE, flushE, saD, saE);
	flopenrc #(2)  	fp3_12(clk, rst, ~stallE, flushE, memtoregD, memtoregE);
	flopenrc #(1)  	fp3_13(clk, rst, ~stallE, flushE, memwriteD, memwriteE);
	flopenrc #(1)  	fp3_14(clk, rst, ~stallE, flushE, alusrcD, alusrcE);
	flopenrc #(1)  	fp3_15(clk, rst, ~stallE, flushE, regdstD, regdstE);
	flopenrc #(1)  	fp3_16(clk, rst, ~stallE, flushE, regwrite_enD, regwrite_enE);
	flopenrc #(8)  	fp3_17(clk, rst, ~stallE, flushE, alucontrolD, alucontrolE);
	flopenrc #(1)  	fp3_18(clk, rst, ~stallE, flushE, gprtohiD, gprtohiE);
	flopenrc #(1)  	fp3_19(clk, rst, ~stallE, flushE, gprtoloD, gprtoloE);
	flopenrc #(32)  fp3_20(clk, rst, ~stallE, flushE, pcD, pcE);
	flopenrc #(1)  	fp3_21(clk, rst, ~stallE, flushE, branchD, branchE);
	flopenrc #(1)  fp3_23(clk, rst, ~stallE, 1'b0  , write_alD, write_alE);
	flopenrc #(8)  fp3_24(clk, rst, ~stallE, flushE, {exceptionD[7],syscallD,breakD,eretD,riD,exceptionD[2:0]},exceptionE);
	flopenrc #(1)  fp3_25(clk, rst, ~stallE , flushE,is_in_delayslotD,is_in_delayslotE);
    flopenrc #(1)  fp3_26(clk, rst, ~stallE, flushE, cp0writeD,cp0writeE);


	//execute stage
	//mux write reg
	mux3 #(32) forwardaemux(srcaE,resultW,aluoutM,forwardaE,srca2E);
	mux3 #(32) forwardbemux(srcbE,resultW,aluoutM,forwardbE,srcb2E);
	mux2 #(32) srcbmux(srcb2E,signimmE,alusrcE,srcb3E);
    mux2 #(32) forwardcp0mux (cp0_data_o,aluoutM,forwardcp0E,cp0toalu);

	alu alu0(.clk(clk),
			 .rst(rst),
			 .alu_num1(srca2E),
	         .alu_num2(srcb3E),
	         .alucontrol(alucontrolE),
			 .hilo(hilo),
			 .sa(saE),
			 .flushE(flushE),
			 .stallM(stallM),
			 .pcplus4E(pcplus4E),
			 .cp0toalu(cp0toalu),
	         .alu_out(aluoutE),
	         .alu_out_64(aluout64E), 
	         .overflowE(overflowE),
	        //  .zeroE(zeroE),
	         .div_stallE(div_stallE),
			 .res_validE(res_validE),
			 .addressErrL(addressErrL),
			 .addressErrS(addressErrS)
	);
	
	branch_judge branch_judge0(
        .branch_judge_controlD(branch_judge_controlD),
        .srca2D(srca2D),
        .srcb2D(srcb2D),
        .branch_takeD(branch_takeD)
    );
    
    //mux write reg
    mux2 #(5) mux_regfile(rtE,rdE,regdstE,writeregE_temp);
    mux2 #(5) mux_al(writeregE_temp,pc_dst_al,write_alE,writeregE);
    
    //EX_MEM flop
	flopenrc#(32) 	fp4_1(clk,rst,~stallM,flushM,aluoutE,aluoutM);
	flopenrc#(5) 	fp4_2(clk,rst,~stallM,flushM,writeregE,writeregM);
	flopenrc#(32) 	fp4_5(clk,rst,~stallM,flushM,pcbranchE,pcbranchM);
	flopenrc#(1) 	fp4_6(clk,rst,~stallM,flushM,branch_takeE,branch_takeM);
	flopenrc#(2) 	fp4_7(clk,rst,~stallM,flushM,memtoregE,memtoregM);
	flopenrc#(1) 	fp4_8(clk,rst,~stallM,flushM,memwriteE,memwriteM);
	flopenrc#(1) 	fp4_9(clk,rst,~stallM,flushM,regwrite_enE,regwrite_enM);
	flopenrc#(8) 	fp4_10(clk,rst,~stallM,flushM,alucontrolE,alucontrolM);
	flopenrc#(1) 	fp4_11(clk,rst,~stallM,flushM,gprtohiE,gprtohiM);
	flopenrc#(1) 	fp4_12(clk,rst,~stallM,flushM,gprtoloE,gprtoloM);
	flopenrc#(32) 	fp4_13(clk,rst,~stallM,flushM,WriteDataE_modified,writedataM);
	flopenrc#(32) 	fp4_14(clk,rst,~stallM,flushM,pcE,pcM);
	flopenrc#(4) 	fp4_15(clk,rst,~stallM,flushM,sig_writeE,sig_writeM);
	flopenrc#(1) 	fp4_16(clk,rst,~stallM,flushM,sig_enE,sig_enM);

	flopenrc #(1)  fp4_17(clk,rst,~stallM,flushM,branch_takeE,branch_takeM);
    flopenrc #(8)  fp4_20(clk,rst,~stallM,flushM,{exceptionE[7:3],overflowE,addressErrL,addressErrS},exceptionM);
	flopenrc #(1)  fp4_21(clk,rst,~stallM,flushM,is_in_delayslotE,is_in_delayslotM);
    flopenrc #(1)  fp4_22(clk,rst,~stallM,flushM,cp0writeE,cp0_writeM);
    flopenrc #(5)  fp4_23(clk,rst,~stallM,flushM,rdE,rdM);	

    
	write_data write_data0(	.alucontrolE(alucontrolE),
							.aluoutE(aluoutE),
							.WriteDataE(srcb2E),
							.sig_writeE(sig_writeE),
							.WriteDataE_modified(WriteDataE_modified),
							.sig_enE(sig_enE)
	);

	//mem stage
	mux4 #(32) resmux_new(aluoutW,readdataW_modified,hi_oW,lo_oW,memtoregW,resultW);
    hilo_reg hilo_reg(clk,rst,exception_en,{gprtohiE,gprtoloE},aluout64E[63:32],aluout64E[31:0],res_validE,hi_oM,lo_oM);
//	assign hilo = exception_en ? hilo : {hi_oM, lo_oM};
    assign hilo = {hi_oM, lo_oM};

    always@(*) begin
        if(rst) cause_o = 32'b0;
        else begin
            cause_o[9:8] = aluoutM[9:8];
	        cause_o[23] = aluoutM[23];
	        cause_o[22] = aluoutM[22];
        end
    end

    assign cause_o_revise = (rdM == 5'b01101 && cp0_writeM) ? cause_o:cp0_cause_o;
    assign pcM_revise = (rdM == 5'b01101 && cp0_writeM) ? pcE : pcM;

    // exception part
    exception exception (rst,exceptionM,exceptionM[1],exceptionM[0],cp0_status_o,
                cause_o_revise,cp0_epc_o, exception_en,exceptiontypeM,pcexceptionM);
    
    assign bad_addr = (exceptionM[7])? pcM : aluoutM; // pc??????bad_addr_i??cM??????????????oad store???
    
	cp0_reg cp0 (
        // input
		.clk 				(clk 			    ),
		.rst 				(rst 			    ),
		.we_i 				(cp0_writeM 		),  
		.waddr_i 			(rdM 			    ),
		.raddr_i 			(rdE 			    ),
		.data_i 			(aluoutM 		    ),
		.int_i 				(int 			    ),
		.excepttype_i 		(exceptiontypeM	    ),
		.current_inst_addr_i(pcM_revise 		),
		.is_in_delayslot_i	(is_in_delayslotM   ),
		.bad_addr_i			(bad_addr		    ),
        // output
		.data_o				(cp0_data_o 	    ),
		.count_o			(cp0_count_o 		), 
		.compare_o			(cp0_compare_o 		),
        
		.status_o			(cp0_status_o 		),    	
		.cause_o			(cp0_cause_o 		),
		.epc_o				(cp0_epc_o 		    ),

		.config_o			(cp0_config_o 		),  
		.prid_o				(cp0_prid_o 		),
		.badvaddr			(cp0_badvaddr 		),
		.timer_int_o		(cp0_timer_int_o	)  
	);


    // MEM_WB flop
	flopenrc#(32) fp5_1(clk,rst,~stallW,flushW,aluoutM,aluoutW);// fault
	flopenrc#(32) fp5_2(clk,rst,~stallW,flushW,readdataM,readdataW);
	flopenrc#(5) fp5_3(clk,rst,~stallW,flushW,writeregM,writeregW);
	flopenrc#(32) fp5_4(clk,rst,~stallW,flushW,hi_oM,hi_oW);
	flopenrc#(32) fp5_5(clk,rst,~stallW,flushW,lo_oM,lo_oW);
	flopenrc#(2) fp5_7(clk,rst,~stallW,flushW,memtoregM,memtoregW);
	flopenrc#(1) fp5_8(clk,rst,~stallW,flushW,regwrite_enM,regwrite_enW);
	flopenrc#(8) fp5_9(clk,rst,~stallW,flushW,alucontrolM,alucontrolW);
	flopenrc#(32) fp5_12(clk,rst,~stallW,flushW,pcM,pcW);


	//writeback stage
 	read_data read_data0(	.alucontrolW(alucontrolW),
							.readdataW(readdataW),
							.dataadrW(aluoutW),
							.readdataW_modified(readdataW_modified)
	);
 
    //DEBUG OUTPUT
	
    assign debug_wb_pc          = pcW;
    assign debug_wb_rf_wen      = {4{regwrite_enW & ~stallW}};
    assign debug_wb_rf_wnum     = writeregW;
    assign debug_wb_rf_wdata    = resultW;

endmodule