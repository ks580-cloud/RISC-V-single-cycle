module pc_top_tb();

logic clk;
logic reset;
logic branch;
logic[31:0] immediate;
logic zero;
logic jump;
logic[31:0] result;
logic jalr;
logic[31:0] pc;


pc_top dut(
    .clk(clk),
    .reset(reset),
    .branch(branch),
    .immediate(immediate),
    .zero(zero),
    .jump(jump),
    .result(result),
    .jalr(jalr),
    .pc(pc)
);

initial begin
       $dumpfile("pc_top_tb.vcd");
       $dumpvars(0, pc_top_tb);
end

initial begin
    clk=0;
    forever #5 clk=~clk;
end

int errors=0;


task check_pc(input string name,input logic[31:0] pc_exp); begin
    if(pc_exp === pc) begin
        $display("PASS: %s",name);
    end
    else begin
        errors++;
        $display("FAIL: %s expected %b but got %b",name,pc_exp,pc);
    end

end

endtask

initial begin
    clk=1'b0;
    reset=1'b1;
    branch=1'b0;
    immediate=0;
    zero=1'b0;
    jump=1'b0;
    result=0;
    jalr=1'b0;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    reset=1'b0;
    @(posedge clk);
    #2;
    check_pc("NORMAL CASE",32'd4);
    @(posedge clk);
    #2;
    check_pc("NORMAL CASE",32'd8);
    @(negedge clk);
    branch = 1; 
    zero = 1; 
    immediate = 32'd16;
    @(posedge clk);
    #2;
    check_pc("branch taken",    32'd24);
    @(negedge clk);
    zero = 0;
    @(posedge clk);
    #2;
    check_pc("branch not taken", 32'd28);
    @(negedge clk);
    branch = 0; 
    zero = 1;
    @(posedge clk);
    #2;
    check_pc("zero without branch", 32'd32);
    @(negedge clk);
    zero = 0; 
    jump = 1; 
    immediate = -32'sd8;
    @(posedge clk);
    #2;
    check_pc("JAL backward",    32'd24);
    @(negedge clk);
    jump = 0; 
    jalr = 1; 
    result = 32'd100;
    @(posedge clk);
    #2;
    check_pc("JALR",            32'd100);
    @(negedge clk);
    result = 32'd201;   
    @(posedge clk);
    #2;                      // odd target, bit 0 should be cleared
    check_pc("JALR clears bit 0", 32'd200);

    if(errors) begin
        $display("FAIL ERROR(s) %0d",errors);
    end
    else begin
        $display("ALL PASSED");
    end
    #2;





    $finish;
end

endmodule

