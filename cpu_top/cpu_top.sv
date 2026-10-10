module cpu_top(
    input logic clk,
    input logic reset
);

logic[31:0] pc;
logic zero;
logic[31:0] immediate;
logic branch;
logic [31:0] ins1;
logic jump;
logic jalr;
logic[31:0] result;

pc_top dut1(
    .clk(clk),
    .reset(reset),
    .zero(zero),
    .immediate(immediate),
    .branch(branch),
    .jalr(jalr),
    .result(result),
    .jump(jump),
    .pc(pc)

);

instr_mem dut2(
    .pc(pc),
    .ins1(ins1)
);

imm_gen dut3(
    .ins1(ins1),
    .immediate(immediate)
);

logic alu_src;
logic mem_read;
logic mem_write;
logic reg_write;
logic[1:0] mem_to_reg;

logic[3:0] alu_op;

control_unit dut4(
    .ins1(ins1),
    .alu_src(alu_src),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .reg_write(reg_write),
    .branch(branch),
    .mem_to_reg(mem_to_reg),
    .jump(jump),
    .jalr(jalr),
    .alu_op(alu_op)
);

logic[31:0] rd_data;

logic[31:0] rs1_data;
logic[31:0] rs2_data;

register dut5(
    .reset(reset),
    .clk(clk),
    .rs1_addr(ins1[19:15]),
    .rs2_addr(ins1[24:20]),
    .rd_addr(ins1[11:7]),
    .rd_data(rd_data),
    .write_enable(reg_write),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

logic[31:0] operand_a;
logic[31:0] operand_b;


alu_operand dut6(
    .alu_src(alu_src),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .immediate(immediate),
    .operand_a(operand_a),
    .operand_b(operand_b)
);


alu dut7(
   .operand_a(operand_a),
   .operand_b(operand_b),
   .alu_op(alu_op),
   .result(result),
   .zero(zero) 
);

logic[31:0] mem_data;

data_mem dut8(
    .mem_read(mem_read),
    .mem_write(mem_write),
    .result(result),
    .clk(clk),
    .rs2_data(rs2_data),
    .mem_data(mem_data)
);

wbmux dut9(
    .result(result),
    .mem_to_reg(mem_to_reg),
    .pc(pc),
    .mem_data(mem_data),
    .rd_data(rd_data)
);

endmodule

