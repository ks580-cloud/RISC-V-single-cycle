module jump_addr(
    input logic[31:0] pc,
    input logic[31:0] immediate,
    output logic[31:0] jump_target

);

assign jump_target=pc+immediate;

endmodule