module core(
    input   wire        clk,
    input   wire        rst,  //low active
    input   wire [5: 0] ext_int,  //6'd0

    // instr sram like
    output  wire        inst_req,
    output  wire        inst_wr,
    output  wire [1: 0] inst_size,
    output  wire [31:0] inst_addr,
    output  wire [31:0] inst_wdata,
    input   wire        inst_addr_ok,
    input   wire        inst_data_ok,
    input   wire [31:0] inst_rdata,

    // data sram like
    output  wire        data_req,
    output  wire        data_wr,
    output  wire [1: 0] data_size,
    output  wire [31:0] data_addr,
    output  wire [31:0] data_wdata,
    input   wire        data_addr_ok,
    input   wire        data_data_ok,
    input   wire [31:0] data_rdata,
    
    //debug signals
	output  wire [31:0] debug_wb_pc,
	output  wire [3 :0] debug_wb_rf_wen,
	output  wire [4 :0] debug_wb_rf_wnum,
	output  wire [31:0] debug_wb_rf_wdata
);

    // inst sram
    wire        inst_sram_en    ;
    wire [3 :0] inst_sram_wen   ;  // no use
    wire [31:0] inst_sram_addr  ;
    wire [31:0] inst_sram_wdata ;  // no use
    wire [31:0] inst_sram_rdata ;
    wire        i_stall         ;
    // data sram
    wire        data_sram_en    ;
    wire [3 :0] data_sram_wen   ;
    wire [31:0] data_sram_addr  ;
    wire [31:0] data_sram_wdata ;
    wire [31:0] data_sram_rdata ;
    wire        d_stall         ;
    wire        all_stall       ;
    
    assign inst_sram_wen   =  4'b0;
    assign inst_sram_wdata = 32'b0;

    datapath datapath(
        .clk        (clk),
        .rst        (rst),
        .int        (ext_int),
        //instr
        .inst_en   (inst_sram_en), 
        .pcF        (inst_sram_addr),
        .instrF     (inst_sram_rdata),
        //data
        // .memwriteM  (),
        .sig_writeM (data_sram_wen),
        .sig_enM    (data_sram_en),
        .aluoutM    (data_sram_addr),
        .writedataM (data_sram_wdata),
        .readdataM  (data_sram_rdata),
        // stall
        .i_stall        (i_stall),
        .d_stall        (d_stall),
        .all_stall      (all_stall),
        // debug
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    // inst sram to sram-like
    i_sram2sraml i_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall(i_stall),
        .all_stall(all_stall),

        //sram like
        .inst_req(inst_req), 
        .inst_wr(inst_wr),
        .inst_size(inst_size),
        .inst_addr(inst_addr),
        .inst_wdata(inst_wdata),
        .inst_addr_ok(inst_addr_ok),
        .inst_data_ok(inst_data_ok),
        .inst_rdata(inst_rdata)
    );

    // //data sram to sram-like
    d_sram2sraml d_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .data_sram_en(data_sram_en),
        .data_sram_addr(data_sram_addr),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_wen(data_sram_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall(d_stall),
        .all_stall(all_stall),

        //sram like
        .data_req(data_req),    
        .data_wr(data_wr),
        .data_size(data_size),
        .data_addr(data_addr),   
        .data_wdata(data_wdata),
        .data_addr_ok(data_addr_ok),
        .data_data_ok(data_data_ok),
        .data_rdata(data_rdata)
    );
endmodule