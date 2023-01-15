module i_sram2sraml(
    input wire clk, rst,
    //sram
    input wire inst_sram_en,
    input wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_rdata,
    output wire i_stall,
    input wire all_stall,

    //sram like
    output wire inst_req, 
    output wire inst_wr,
    output wire [1:0] inst_size,
    output wire [31:0] inst_addr,
    output wire [31:0] inst_wdata,
    input wire inst_addr_ok,
    input wire inst_data_ok,
    input wire [31:0] inst_rdata
);
    reg addr_rcv;      //地址握手成功
    reg do_finish;     //读事务结束

    always @(posedge clk) begin
        addr_rcv <= rst          ? 1'b0 :  //rst为0
                    //在req拉高的情况下，收到指令地址到达并返回ok信号后
                    //且还没有传输数据的情况下，拉高地址握手信号
                    //注意需要先保证req信号的高电平，如果addrok和dataok同时，
                    //需要保证先dataok在addrok，dataok可能对应上一个addrok，为减少stall周期，需先完成
                    
                    inst_req & inst_addr_ok? 1'b1 :
                    //直到收到数据返回信号之后才拉低信号
                    inst_data_ok ? 1'b0 : addr_rcv;
    end

    always @(posedge clk) begin
        do_finish <= rst          ? 1'b0 : //rst为0
                    //收到数据返回信号后，表示一次读事务结束
                     inst_data_ok ? 1'b1 :
                     ~all_stall ? 1'b0 : do_finish;
    end

    //save rdata
    //存储上次读取的数据
    reg [31:0] inst_rdata_save;
    always @(posedge clk) begin
        inst_rdata_save <= rst ? 32'b0:
                           inst_data_ok ? inst_rdata : inst_rdata_save;
    end

    //sram like
    //req一直拉高直到地址握手成功或事务结束
    assign inst_req = inst_sram_en & ~addr_rcv & ~do_finish;
    assign inst_wr = 1'b0;
    assign inst_size = 2'b10;
    assign inst_addr = inst_sram_addr;
    assign inst_wdata = 32'b0;

    //sram
    assign inst_sram_rdata = inst_rdata_save;
    //在instsram使能且未结束过程中，像datapath传输istall信号，会stall所有流水线
    assign i_stall = inst_sram_en & ~do_finish;
endmodule