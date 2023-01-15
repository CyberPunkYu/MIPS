`timescale 1ns / 1ps

module hilo_reg(
	input  wire clk,rst,
	input  wire exception_en,
	input  wire [1:0] wconfig,  //[1] for hi write, [0] for lo write
	input  wire [31:0] hi_i, lo_i,
	input  wire res_validE,
	output wire [31:0] hi_o, lo_o
    );
	
	reg [31:0] hi, lo;
	always @(posedge clk) begin
		if(rst) begin
			hi <= 0;
			lo <= 0;
		end else if (exception_en) begin
            hi <= hi;
            lo <= lo;
		end else begin	
        	if(&wconfig & res_validE) begin
                hi <= hi_i;
				lo <= lo_i;
			end
            else if(wconfig[1] & ~wconfig[0] & ~res_validE)
                hi <= hi_i;
            else if(wconfig[0] & ~wconfig[1] & ~res_validE)
                lo <= lo_i;
            else begin
				hi <= hi;
                lo <= lo;
			end
        end
	end

	assign hi_o = hi;
	assign lo_o = lo;
endmodule