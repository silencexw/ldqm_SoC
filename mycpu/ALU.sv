`timescale 1ns/1ps
`include "InstrDefine.svh"
module ALU #(
    parameter CTRL_CLO_CLZ = 1'b0
) (
	input [31:0] a,
	input [31:0] b,
	input [3:0] ALUControl,
	input OvCtrl,
	input WrCtrl,
	output logic [31:0] ALUResult,
	output logic ov,
	output logic write_reg//for conditional instr, such as mov*
);
/*
assign ALUResult = (ALUControl == `AND) ? a & b : 
					(ALUControl == `OR) ? a | b : 
					(ALUControl == `ADD) ? a + b : 
					(ALUControl == `SUB) ? a - b : 
					(ALUControl == `SLT ) ? $signed(a) < $signed(b) : 
					(ALUControl == `SLTU) ? a < b : 32'hzzzzzzzz;
*/
//assign Zero = (ALUResult == 32'h0) ? 1'b1 : 1'b0;
logic [32:0] temp;
logic [31:0] loz;
logic _write_reg;
always_comb begin
    temp = '0;
    _write_reg = 1'b1;
	case(ALUControl)
	    `LL: begin //�߼�����
	        ALUResult = b << a[4:0];
	        ov = 1'b0 & OvCtrl;
	    end
	    `RA: begin //��������
	        ALUResult = $signed($signed(b) >>> a[4:0]);
	        ov = 1'b0 & OvCtrl;
	    end
	    `RL: begin //�߼�����
	        ALUResult = b >> a[4:0];
	        ov = 1'b0 & OvCtrl;
	    end
		`AND: begin
		    ALUResult = a & b;
			ov = 1'b0 & OvCtrl;
		end
		`OR: begin
			ALUResult = a | b;
			ov = 1'b0 & OvCtrl;
		end
		`ADD: begin
			temp = {a[31], a} + {b[31], b};
			ov = (temp[32] != temp[31]) & OvCtrl;
			ALUResult = temp[31:0];
		end
		`SUB: begin
			temp = {a[31], a} - {b[31], b};
			ov = (temp[32] != temp[31]) & OvCtrl;
			ALUResult = temp[31:0];
		end
		`SLT: begin
			ALUResult = $signed(a) < $signed(b) ? 32'h1 : 32'h0;
			ov = 1'b0 & OvCtrl;
		end
		`SLTU: begin
			ALUResult = {1'b0, a} < {1'b0, b} ? 32'h1 : 32'h0;
			ov = 1'b0 & OvCtrl;
		end
		`XOR: begin
		    ALUResult = a ^ b;
		    ov = 1'b0 & OvCtrl;
		end
		`NOR: begin
		    ALUResult = ~(a | b);
		    ov = 1'b0 & OvCtrl;
		end
		`LUI: begin
			ALUResult = {b[15:0], 16'h0};
			ov = 1'b0 & OvCtrl;
		end
		`CLZ: begin
		  ALUResult = loz;
		  ov = 1'b0;
		end
		`CLO: begin
		  ALUResult = loz;
		  ov = 1'b0;
		end
		`MOVZ: begin
		  ALUResult = b == '0 ? a : 0;
		  ov = 1'b0;
		  _write_reg = b == '0 ? 1'b1 : 1'b0;
		end
		`MOVN: begin
		  ALUResult = b ? a : 0;
		  ov = 1'b0;
		  _write_reg = b ? 1'b1 : 1'b0;
		end
		default: begin
		  ALUResult = '0;
		  ov = '0;
		end
	endcase // ALUControl
	write_reg = ~WrCtrl ? 1'b1 : _write_reg;
end

//count leading ones or zeros
wire [3:0] tmp_oz [3:0];
wire bit_counter_op = ALUControl == `CLO ? 1'b1 : 1'b0;
generate
    if (CTRL_CLO_CLZ) begin
    for (genvar i = 0; i < 4; i++) begin
        byte_bit_counter bbc(
            .op(bit_counter_op),
            .src(a[i*8+7 : i*8]),
            .res(tmp_oz[i])
        );
    end
    end
endgenerate
if (CTRL_CLO_CLZ) begin
assign loz = (tmp_oz[3] != 4'd8) ? tmp_oz[3] + 32'd0 : 
            (tmp_oz[2] != 4'd8) ? tmp_oz[2] + 32'd8 : 
            (tmp_oz[1] != 4'd8) ? tmp_oz[1] + 32'd16 : 
            tmp_oz[0] + 32'd24;
end
else begin
assign loz = '0;
end
endmodule// : ALU

module byte_bit_counter (
    input logic op,
    input logic [7:0] src,
    output logic [3:0] res
);
always_comb begin
    if (op) begin
        casez (src)
            8'b0???????: res = 4'd0;
            8'b10??????: res = 4'd1;
            8'b110?????: res = 4'd2;
            8'b1110????: res = 4'd3;
            8'b11110???: res = 4'd4;
            8'b111110??: res = 4'd5;
            8'b1111110?: res = 4'd6;
            8'b11111110: res = 4'd7;
            8'b11111111: res = 4'd8;
        endcase
    end
    else begin
        casez (src)
            8'b1???????: res = 4'd0;
            8'b01??????: res = 4'd1;
            8'b001?????: res = 4'd2;
            8'b0001????: res = 4'd3;
            8'b00001???: res = 4'd4;
            8'b000001??: res = 4'd5;
            8'b0000001?: res = 4'd6;
            8'b00000001: res = 4'd7;
            8'b00000000: res = 4'd8;
        endcase
    end
end
endmodule