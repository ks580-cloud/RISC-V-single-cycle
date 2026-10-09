module data_mem(
    input logic mem_read,
    input logic mem_write,
    input logic[31:0] result, //from ALU
    input logic clk,
    input logic[31:0] rs2_data,
    output logic[31:0] mem_data

);

logic [31:0]datamem [0:255];

always_comb begin
    mem_data=32'd0;
    if(mem_read==1'b1) begin
        mem_data=datamem[result[9:2]];
    end
end

always_ff @(posedge clk) begin
    if(mem_write==1'b1) begin
        datamem[result[9:2]]<=rs2_data;
    end
end

endmodule

