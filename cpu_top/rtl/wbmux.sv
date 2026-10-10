module wbmux(

    input logic[31:0] result,
    input logic[1:0] mem_to_reg,
    input logic[31:0] mem_data,
    input logic[31:0] pc,
    output logic[31:0] rd_data


);

logic[31:0] pcplus4;

pc_adder pp1(
    .pc(pc),
    .pcplus4(pcplus4)
);


always_comb begin
    rd_data=32'd0;
    case(mem_to_reg) 
        2'b00:rd_data=result;
        2'b01:rd_data=mem_data;
        2'b10:rd_data=pcplus4;
    
endcase


     
    
end

endmodule

