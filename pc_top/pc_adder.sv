module pc_adder(
    input logic[31:0] pc,
    output logic[31:0] pcplus4
);

assign pcplus4=pc+32'd4;

endmodule

