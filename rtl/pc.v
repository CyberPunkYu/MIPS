`timescale 1ns / 1ps

module pc #(parameter WIDTH = 32)(
	input wire clk,rst,en,
	input wire [WIDTH-1:0] pcnext,
	output reg [WIDTH-1:0] pc,
	output reg ce
    );
	initial begin
		pc <= 32'hbfc00000;
	end

	always @(posedge clk) begin
        if(rst) begin
            ce <= 0;
        end
        else begin
            ce <= 1;
        end
    end
	always @(posedge clk) begin
		if(!ce) begin
			pc <= 32'hbfc00000;
			end
		else if(en) begin
			pc <= pcnext;
		end 
	end

endmodule
