module mycpu_top(
    input wire clk,
    input wire resetn,  //low active
    input wire [5:0] ext_int,  //6'd0

    //cpu inst sram
    output        inst_sram_en   ,
    output [3 :0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    //cpu data sram
    output        data_sram_en   ,
    output [3 :0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    
    //debug signals
	output wire [31:0] debug_wb_pc,
	output wire [3 :0] debug_wb_rf_wen,
	output wire [4 :0] debug_wb_rf_wnum,
	output wire [31:0] debug_wb_rf_wdata
);

// 闂佽法鍣﹂幏??婵炴垶鎼╂禍娆戞閵夆晜鏅搁柨鐕傛嫹?
	wire [31:0] pc;
	wire [31:0] instr;
	wire [39:0] ascii;
	wire memwrite;

    // 濠⒀呭仜婵偤宕樺▎搴♀枏闁艰櫕鍨濇穱濠囧矗閿??
    wire [3:0] sig_writeM;
    wire sig_enM;

	wire [31:0] aluout, writedata, readdata;

    wire [31:0] inst_paddr,data_paddr;

    datapath datapath(
        .clk(~clk),
        .rst(~resetn),
        .int(ext_int),
        //instr
        .inst_enF(inst_en),
        .pcF(pc),                    //pcF
        .instrF(instr),              //instrF
        //data
        // .data_en(data_en),
        .memwriteM(memwrite),
        // 濠⒀呭仜婵偤宕樺▎搴♀枏闁艰櫕鍨濇穱濠囧矗閿??
        .sig_writeM(sig_writeM),
        .sig_enM(sig_enM),
        .aluoutM(aluout),
        .writedataM(writedata),
        .readdataM(readdata),

        // stall
        .i_stall(i_stall),
        .d_stall(d_stall),
        .all_stall(all_stall),

        .debug_wb_pc       (debug_wb_pc       ),  
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),  
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),  
        .debug_wb_rf_wdata (debug_wb_rf_wdata )        
    );

    // //inst sram to sram-like
    // i_sram2sraml i_sram_to_sram_like(
    //     .clk(clk), .rst(rst),
    //     //sram
    //     .inst_sram_en(inst_sram_en),
    //     .inst_sram_addr(inst_sram_addr),
    //     .inst_sram_rdata(inst_sram_rdata),
    //     .i_stall(i_stall),
    //     .all_stall(all_stall),

    //     //sram like
    //     .inst_req(inst_req), 
    //     .inst_wr(inst_wr),
    //     .inst_size(inst_size),
    //     .inst_addr(inst_addr),   
    //     .inst_wdata(inst_wdata),
    //     .inst_addr_ok(inst_addr_ok),
    //     .inst_data_ok(inst_data_ok),
    //     .inst_rdata(inst_rdata)
    // );

    // //data sram to sram-like
    // d_sram2sraml d_sram_to_sram_like(
    //     .clk(clk), .rst(rst),
    //     //sram
    //     .data_sram_en(data_sram_en),
    //     .data_sram_addr(data_sram_addr),
    //     .data_sram_rdata(data_sram_rdata),
    //     .data_sram_wen(data_sram_wen),
    //     .data_sram_wdata(data_sram_wdata),
    //     .d_stall(d_stall),
    //     .all_stall(all_stall),

    //     //sram like
    //     .data_req(data_req),    
    //     .data_wr(data_wr),
    //     .data_size(data_size),
    //     .data_addr(data_addr),   
    //     .data_wdata(data_wdata),
    //     .data_addr_ok(data_addr_ok),
    //     .data_data_ok(data_data_ok),
    //     .data_rdata(data_rdata)
    // );
    assign inst_sram_en = 1'b1;     //婵犵?鍐??褰掓倶婢舵劕瀚夊┑澶屾箯st_en闂佹寧绋戦懟顖氼潩閵娾晜鍋ㄩ柍渚珵st_en
    assign inst_sram_wen = 4'b0;
    // assign inst_sram_addr = pc;
    assign inst_sram_addr = inst_paddr;
    assign inst_sram_wdata = 32'b0;
    assign instr = inst_sram_rdata;

    assign data_sram_en = sig_enM;     //婵犵?鍐??褰掓倶婢舵劕瀚夊┑澶屽ta_en闂佹寧绋戦懟顖氼潩閵娾晜鍋ㄩ柍铏瑰毎ta_en
    assign data_sram_wen = sig_writeM;
    // assign data_sram_addr = aluout;
    assign data_sram_addr = data_paddr;
    assign data_sram_wdata = writedata;
    assign readdata = data_sram_rdata;

    //ascii for debug
    instdec instdec(
        .instr(instr),
        .ascii(ascii)
    );

    mmu mmu(
        .inst_vaddr(pc),
        .inst_paddr(inst_paddr),
        .data_vaddr(aluout),
        .data_paddr(data_paddr)
    );
endmodule