module pc_top(
    input logic clk,
    input logic reset,
    input logic branch,
    input logic[31:0] immediate,
    input logic zero,
    input logic jump,
    input logic[31:0] result,
    input jalr,
    output logic[31:0] pc

);

logic[31:0] pc_next;
logic[31:0] pcplus4;
logic branch_taken;
logic[31:0] branch_target;
logic[31:0] jump_target;


programcounter p1(
    .clk(clk),
    .reset(reset),
    .pc_next(pc_next),
    .pc(pc)
);

pc_adder p2(
    .pc(pc),
    .pcplus4(pcplus4)
);

branch_addr p3(
    .pc(pc),
    .immediate(immediate),
    .branch_target(branch_target)

);

jump_addr p4(
    .pc(pc),
    .immediate(immediate),
    .jump_target(jump_target)

);

assign branch_taken=branch & zero;

always_comb begin
    if(branch_taken) begin
        pc_next=branch_target;
    end
    else if(jump) begin
        pc_next=jump_target;
    end
    else if(jalr) begin
        pc_next={result[31:1],1'b0}; //we are adding 0 in the LSB because PC value must be a multiple of 2 and if the ALU result is 201..its rounded off to the nearest PC value which is 200.
    end
    else begin
        pc_next=pcplus4;
    end
    
end










endmodule

