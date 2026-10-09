module branch_addr(
    input logic[31:0] pc,
    input logic[31:0] immediate,
    output logic[31:0] branch_target

);

assign branch_target=pc+immediate;

endmodule