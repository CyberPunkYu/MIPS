`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/11/26 01:20:15
// Design Name: 
// Module Name: d_cache_WB_2way
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


//直接映射+写回+两路组相联
module d_cache_WB_2way (
    input wire clk, rst,
    //mips core  cpu<-->cache
    input         cpu_data_req     , // 读写请求信号
    input         cpu_data_wr      , // 写请求信号
    input  [1 :0] cpu_data_size    , // 由地址最低两位，确定有效字节长度（即写掩码）
    input  [31:0] cpu_data_addr    , // 数据地址
    input  [31:0] cpu_data_wdata   , // 待写入数据
    output [31:0] cpu_data_rdata   , // 待读出数据
    output        cpu_data_addr_ok , // cache间接传递 内存的地址确认
    output        cpu_data_data_ok , // cache间接传递 内存的数据确认(已写入/已读出)

    //axi interface   cache<-->mem
    output         cache_data_req     , // 读写请求信号
    output         cache_data_wr      , // 写请求信号
    output  [1 :0] cache_data_size    , // 由地址最低两位，确定有效字节长度（即掩码）
    output  [31:0] cache_data_addr    , // 数据地址
    output  [31:0] cache_data_wdata   , // 待写入内存的数据
    input   [31:0] cache_data_rdata   , // 从内存中读出的数据
    input          cache_data_addr_ok , // 内存的地址确认
    input          cache_data_data_ok   // 内存的数据确认(已写入/已读出)
);
    // Cache参数配置
    // 设置Index位宽为10，offset位宽为2，Tag位宽为20
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    // 由Index位宽可知Cache的深度为2^10
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
    //Cache存储单元
    // 设置位宽为1的valid寄存器 x2
    reg                 cache_valid [CACHE_DEEPTH - 1 : 0][1:0];
    // 注意：写回机制需要设置位宽为1的dirty寄存器 x2
    reg                 cache_dirty [CACHE_DEEPTH - 1 : 0][1:0];
    // 注意：组相联时需要标记使用情况，以便替换出不常用的块
    reg                 cache_hot [CACHE_DEEPTH - 1 : 0][1:0];
    // 设置位宽为20的Tag寄存器 x2
    reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0][1:0];
    // 设置位宽为32的 块单字 存储单元 x2
    reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0][1:0];

    // 访问地址分解，截取Tag,Index,Offset
    wire [TAG_WIDTH-1:0] tag;
    wire [INDEX_WIDTH-1:0] index;
    wire [OFFSET_WIDTH-1:0] offset;
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];

    // 根据Index访问对应的Cache line
    wire c_valid[1:0];
    // 注意：新增dirty位
    wire c_dirty[1:0];
    // 注意：新增hot位
    wire c_hot[1:0]; 
    wire [TAG_WIDTH-1:0] c_tag[1:0];
    wire [31:0] c_block[1:0];
    // 以下赋值均注意要读出 两路 的参数
    assign c_valid[0] = cache_valid[index][0];
    assign c_valid[1] = cache_valid[index][1];
    // 注意：获取新增的dirty位
    assign c_dirty[0] = cache_dirty[index][0]; 
    assign c_dirty[1] = cache_dirty[index][1]; 
    // 注意：获取新增的hot位
    assign c_hot[0] = cache_hot[index][0];
    assign c_hot[1] = cache_hot[index][1];
    assign c_tag  [0] = cache_tag  [index][0];
    assign c_tag  [1] = cache_tag  [index][1];
    assign c_block[0] = cache_block[index][0];
    assign c_block[1] = cache_block[index][1];

    // 判断是否命中
    wire hit, miss;
    // 注意：当且仅当 存在某路的 valid位为1，且Tag与之匹配时==>hit，否则==>miss
    assign hit = c_valid[0] & (c_tag[0] == tag) | c_valid[1] & (c_tag[1] == tag); 
    assign miss = ~hit;

    // 注意：新增路径选择
    // hit ==> 直接使用hit的路径
    // miss ==> 由于miss后需要替换出一个cache line，所以要选择 最近不常用 的路径
    wire c_way;
    assign c_way = hit ? ( c_valid[0] & (c_tag[0] == tag) ? 1'b0 : 1'b1) : 
                        c_hot[0] ? 1'b1 : 1'b0;

    // 读写信号
    wire read, write;
    assign write = cpu_data_wr;
    assign read = ~write;

    // 注意：获取当前cache line的dirty情况
    wire dirty, clean; 
    assign dirty = c_dirty[c_way]; 
    assign clean = ~dirty;

    // FSM 写回机制的状态转换机
    // IDLE闲置状态     RM读内存    WM写内存
    parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b11;
    // 状态寄存器
    reg [1:0] state;
    // 注意：新增load_finish用于确认写缺失过程中，是否已经将旧值读入cache
    // 由此来判断是否已经可以向cache写入新值
    reg load_finish;

    // 定义前移
    // 保存地址中的tag, index，防止addr发生改变
    // 注意：额外保存c_way，防止发生变化
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    reg c_way_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_data_req ? tag : tag_save;
        index_save <= rst ? 0 :
        // 有读写请求才更新，否则保持不变
                      cpu_data_req ? index : index_save;
        c_way_save <= rst ? 0 :
        // 有读写请求才更新，否则保持不变
                      cpu_data_req ? c_way : c_way_save;
    end

    always @(posedge clk) begin
        if(rst) begin
            // 初始化时，状态置为IDLE
            state <= IDLE;
            load_finish <= 1'b0;
        end
        else begin
            case(state)
            // 根据状态转换条件进行转换
                IDLE:begin
                    if (cpu_data_req) begin
                        // 收到读写请求时==>进行状态转换
                        if (hit) begin
                        // 读写命中==>保持空闲
                            state <= IDLE;
                            // 读写命中后更新hot位
                            // 选中路径hot位 置1
                            cache_hot[index][c_way] <= 1'b1;
                            // 注意：同时给未选中路径hot位 置0
                            cache_hot[index][~c_way] <= 1'b0;
                        end
                        else if (miss & clean) 
                        // 读写缺失且为干净块==>读内存
                            state <= RM;
                        else if (miss & dirty)
                        // 读写缺失且为脏块==>写内存
                            state <= WM;
                    end
                    else begin
                    // 未收到状态转换==>保持空闲
                        state <= IDLE;
                    end
                    load_finish <= 1'b0;
                end

                RM:begin
                    if (cache_data_data_ok) begin
                    // mem传回ok信息==>空闲
                        state <= IDLE;
                        // 读写缺失处理完毕时更新hot位，注意使用是先保存的index_save和c_way_save
                        // 选中路径hot位 置1
                        cache_hot[index_save][c_way_save] <= 1'b1;
                        // 注意：同时给未选中路径hot位 置0
                        cache_hot[index_save][~c_way_save] <= 1'b0;
                    end
                    else 
                    // mem未传回ok信息==>保持读内存
                        state <= RM;
                    load_finish <= 1'b1;
                end

                WM:begin
                    if (cache_data_data_ok)
                    // mem传回ok信息==>开始读内存（脏块写回完毕，读取正确数据）
                        state <= RM;
                    else
                    // mem未传回ok信息==>保持写内存
                        state <= WM;
                end
            endcase
        end
    end

    //读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    wire read_req;      // 一次完整的读事务，从发出读请求到结束 (当前是否为RM状态)
    reg addr_rcv;       // 地址接收成功(addr_ok)后到读请求结束
    wire read_finish;   // 数据接收成功(data_ok)，即读请求结束 (当前处于RM状态，且已经得到读取的数据)
    always @(posedge clk) begin
        addr_rcv <= // 重置 ==> 置0
                    rst ? 1'b0 :
                    // 当前处于RM状态 且 有读写请求 且 mem确认addr已经收到 ==> 置1
                    // 注意：原read ==> 新read_req 
                    // 写回机制中 写指令也可能需要读内存(脏块写回完毕，要读取正确数据)
                    read_req & cache_data_req & cache_data_addr_ok ? 1'b1 : 
                    // 数据接收成功(即本次请求已结束) ==> 置0
                    read_finish ? 1'b0 : 
                    // 否则 ==> 保持不变
                    addr_rcv;
    end
    assign read_req = state==RM;    //当前是否为RM状态
    assign read_finish = read_req & cache_data_data_ok;

    //写内存
    wire write_req;     // 当前是否为WM状态
    reg waddr_rcv;      // 地址接收成功(addr_ok)后到写请求结束
    wire write_finish;  // 数据写入成功(data_ok)，即写请求结束 (当前处于WM状态，且已经将数据写入主存)
    always @(posedge clk) begin
        waddr_rcv <= //重置 ==> 置0
                     rst ? 1'b0 :
                     // 当前处于WM状态 且 有读写请求 且 mem确认addr已经收到 ==> 置1
                     // 注意：原write ==> 新write_req 
                     // 写回机制中 读指令可能会需要写内存(hit & dirty时要先写回脏块)
                     write_req & cache_data_req & cache_data_addr_ok ? 1'b1 :
                     // 数据写入成功(即本次请求已结束) ==> 置0
                     write_finish ? 1'b0 :
                     // 否则 ==> 保持不变
                     waddr_rcv;
    end
    assign write_req = state==WM;   //当前是否为WM状态
    assign write_finish = write_req & cache_data_data_ok;

    // output to mips core
    // hit ==> 直接读cache || miss ==> 读内存   
    // 注意：此处要读命中的那路cache line
    assign cpu_data_rdata   = hit ? c_block[c_way] : cache_data_rdata;
    // 向CPU确认地址
    // hit ==> 直接确认 有读写请求&确认命中
    // miss ==> 间接传递 有读写内存的请求&内存回复已确认地址
    assign cpu_data_addr_ok = (cpu_data_req & hit) | (cache_data_req & cache_data_addr_ok );
    // 向CPU确认数据
    // hit ==> 直接确认 有读写请求&确认命中
    // miss ==> 间接传递 处于RM阶段&内存回复已确认地址
    // 此处注意在写分配时，虽然是块单字，但是可能存在半字操作，
    // 所以需要先从主存中读出数据再写入cache，否则会覆盖掉原有的无关数据，因此是处于RM阶段时进行确认
    assign cpu_data_data_ok = (cpu_data_req & hit) | ( read_req & cache_data_data_ok );

    // output to axi interface
    // 数据请求信号：有读写请求，且请求开始但尚未结束时置1
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    // 写请求信号：处于WM状态时置1
    // 注意：原cpu_data_wr ==> 新write_req  
    // 因为写回机制中 写操作可能（写缺失时）会经历RM、WM两种状态，而只有WM状态下才需要对主存进行写操作
    assign cache_data_wr    = write_req;
    // 有效字节长度：间接传递即可
    // 读指令：有效字节固定为4B（块单字）
    // 写指令：sb ==> 1B   |   sh ==> 2B    |   sw ==> 4B
    assign cache_data_size  = cpu_data_size;
    // 写数据地址：分读写两种情况
    // 读内存：间接传递即可
    // 写内存：传递脏数据的地址
    // 注意1：写内存中 原cpu_data_addr ==> 新{c_tag[c_way], index, offset}
    // 注意2：此处要指定好路径
    assign cache_data_addr  = cache_data_wr ? {c_tag[c_way], index, offset}:
                                            cpu_data_addr;
    // 写数据内容：
    // 注意1：原cpu_data_wdata ==> c_block[c_way]
    // 因为在写回机制中，只有来自cache的脏数据才需要写入主存中
    // 注意2：同样的，注意指定路径
    assign cache_data_wdata = c_block[c_way];

    // 写入Cache
    wire [31:0] write_cache_data;
    wire [3:0] write_mask;

    // 根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

    // 掩码的使用：位为1的代表需要更新的。
    // 位拓展：{8{1'b1}} -> 8'b11111111
    // new_data = old_data & ~mask | write_data & mask
    // 注意：任然是要指定好路径c_way
    assign write_cache_data = cache_block[index][c_way] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

    integer i, j;
    always @(posedge clk) begin
        if(rst) begin
            // 注意：此处要初始化两路cache
            for(i=0; i<CACHE_DEEPTH; i=i+1) begin
                for (j=0; j<2; j=j+1) begin
                    // 初始化时Cache置为无效
                    cache_valid[i][j] <= 0;
                    // 注意：初始化dirty位
                    cache_dirty[i][j] <= 0;
                    // 注意：初始化hot位
                    cache_hot[i][j] <= 0;
                end
            end
        end
        else begin
            // 读缺失，访存结束时
            if(read_finish) begin
            // 注意1：读缺失时，需要先从内存中读出数据到cache，有延迟，所以要使用保存的原index(index_save)
            // 注意2：指定路径
                cache_valid[index_save][c_way_save] <= 1'b1; // 将Cache line置为有效
                // 注意：添加新cache line dirty位的初始化
                cache_dirty[index_save][c_way_save] <= 1'b0; 
                cache_tag  [index_save][c_way_save] <= tag_save; // 用当前指令的tag更新cache_tag
                cache_block[index_save][c_way_save] <= cache_data_rdata; // 写入Cache line
            end
            // 写指令：分 写命中 / 写缺失 两种情况
            else if(write & hit) begin
            // 写命中：直接写入cache line
                // 注意1：写命中时，直接向cache中写入数据，因此直接使用index
                // 倘若使用index_save，则不能保证使用时index_save已经完成更新，反而会出错
                // 注意2：写cache line时 标记dirty
                // 注意3：指定路径
                cache_dirty[index][c_way] <= 1'b1; 
                cache_block[index][c_way] <= write_cache_data;
            end
            else if(write & load_finish) begin
            // 写缺失：确保已经已经加载过旧数据后，再写入cache line
                // 注意1：写缺失时，需要等待旧值读入，存在延迟，所以此处需要使用保存的原index(index_save)
                // 注意2：写cache line时 标记dirty
                // 注意3：指定路径
                cache_dirty[index_save][c_way_save] <= 1'b1; 
                cache_block[index_save][c_way_save] <= write_cache_data;
            end
        end
    end
endmodule
