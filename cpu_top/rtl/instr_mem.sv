module instr_mem(
    input logic[31:0] pc,
    output logic[31:0] ins1
);

logic [31:0]insmem [0:255];

assign ins1=insmem[pc[9:2]];

endmodule 