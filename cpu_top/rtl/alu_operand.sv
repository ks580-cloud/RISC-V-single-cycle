module alu_operand(
    input logic alu_src,
    input logic[31:0] rs1_data,
    input logic[31:0] rs2_data,
    input logic[31:0] immediate,
    output logic[31:0] operand_a,
    output logic[31:0] operand_b

);

always_comb begin
    operand_a=32'd0;
    operand_b=32'd0;
    case(alu_src)
    1'b0:begin
        operand_a=rs1_data;
        operand_b=rs2_data;
    end
    1'b1:begin
        operand_a=rs1_data;
        operand_b=immediate;
    end
endcase
end

endmodule



