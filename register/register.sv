module register(

    input logic clk,
    input logic reset,
    input logic [4:0]rs1_addr,
    input logic [4:0]rs2_addr,
    input logic [4:0]rd_addr,
    input logic [31:0]rd_data,
    input logic write_enable,
    output logic [31:0]rs1_data,
    output logic [31:0]rs2_data
);

logic [31:0]regfile [31:0];


always_ff @(posedge clk)begin
    if(reset) begin
    end
    else if(write_enable && rd_addr!=5'd0) begin
        regfile[rd_addr]<=rd_data;
    end
end         


assign rs1_data=(rs1_addr==5'd0)?32'd0:regfile[rs1_addr];
assign rs2_data=(rs2_addr==5'd0)?32'd0:regfile[rs2_addr];

endmodule
        

