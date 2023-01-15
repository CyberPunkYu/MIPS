module d_sram2sraml(
    input wire clk, rst,
    //sram
    input wire data_sram_en,
    input wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_rdata,
    input wire [3:0] data_sram_wen,
    input wire [31:0] data_sram_wdata,
    output wire d_stall,
    input wire all_stall,

    //sram like
    output wire data_req, 
    output wire data_wr,
    output wire [1:0] data_size,
    output wire [31:0] data_addr,   
    output wire [31:0] data_wdata,
    input wire [31:0] data_rdata,
    input wire data_addr_ok,
    input wire data_data_ok
);
    reg addr_rcv;      //地址握手成功
    reg do_finish;     //读写事务结束

    always @(posedge clk) begin
        addr_rcv <= rst          ? 1'b0 :
                    //在req拉高的情况下，收到指令地址到达并返回ok信号后
                    //且还没有传输数据的情况下，拉高地址握手信号
                    //注意需要先保证req信号的高电平，如果addrok和dataok同时，
                    //需要保证先dataok在addrok，dataok可能对应上一个addrok，为减少stall周期，需先完成
                    data_req & data_addr_ok? 1'b1 :
                    //直到收到数据返回信号之后才拉低信号
                    data_data_ok ? 1'b0 : addr_rcv;
    end

    always @(posedge clk) begin
        do_finish <= rst          ? 1'b0 :
                    //收到数据返回信号后，表示一次读写事务结束
                     data_data_ok ? 1'b1 :
                     ~all_stall   ? 1'b0 : do_finish;
    end

    //save rdata
     //存储上次读取的数据
    reg [31:0] data_rdata_save;
    always @(posedge clk) begin
        data_rdata_save <= rst ? 32'b0:
                           data_data_ok ? data_rdata : data_rdata_save;
    end

    //sram like
    //req一直拉高直到地址握手成功或事务结束
    assign data_req = data_sram_en & ~addr_rcv & ~do_finish;
    //如果wen不为00，则为写操作
    assign data_wr = data_sram_en & |data_sram_wen;
    //根据wen判断size大小，具体可看类sram接口数据有效情况
    assign data_size = (data_sram_wen==4'b0001 || data_sram_wen==4'b0010 || data_sram_wen==4'b0100 || data_sram_wen==4'b1000) ? 2'b00:
                       (data_sram_wen==4'b0011 || data_sram_wen==4'b1100 ) ? 2'b01 : 2'b10;
    assign data_addr = data_sram_addr;
    assign data_wdata = data_sram_wdata;

    //sram
    assign data_sram_rdata = data_rdata_save;
    //在instsram使能且未结束过程中，像datapath传输dstall信号，会stall所有流水线
    assign d_stall = data_sram_en & ~do_finish;
endmodule