module data_mem_tb();

logic clk;
logic mem_read;
logic mem_write;
logic[31:0] result;
logic[31:0] rs2_data;
logic[31:0] mem_data;

data_mem dut(
    .mem_read(mem_read),
    .mem_write(mem_write),
    .result(result),
    .clk(clk),
    .rs2_data(rs2_data),
    .mem_data(mem_data)
);

initial begin
    clk=0;
    forever #5 clk=~clk;
end

initial begin
    $dumpfile("data_mem_tb.vcd");
    $dumpvars(0,data_mem_tb);
end

int errors=0;

task check_mem(input string name,input logic[31:0] exp); begin
    if(mem_data === exp) begin
        $display("PASS: %s",name);
    end
    else begin
        errors++;
        $display("FAIL: %s expected %0d but got %0d",name,exp,mem_data);
    end
end
endtask

initial begin
    mem_read=1'b0;
    mem_write=1'b0;
    result=0;
    rs2_data=0;

    // store 0xDEADBEEF at address 8 and 55 at address 12
    @(negedge clk);
    mem_write=1'b1;
    result=32'd8;
    rs2_data=32'hDEADBEEF;
    @(negedge clk);
    result=32'd12;
    rs2_data=32'd55;
    @(negedge clk);
    mem_write=1'b0;

    // read them back
    mem_read=1'b1;
    result=32'd8;
    #2;
    check_mem("load addr 8",32'hDEADBEEF);
    @(negedge clk);
    result=32'd12;
    #2;
    check_mem("load addr 12",32'd55);

    // read disabled
    @(negedge clk);
    mem_read=1'b0;
    result=32'd8;
    #2;
    check_mem("read disabled gives 0",32'd0);

    // write disabled, memory must keep its old value
    @(negedge clk);
    rs2_data=32'd1;
    @(posedge clk);
    #2;
    mem_read=1'b1;
    #2;
    check_mem("no write when disabled",32'hDEADBEEF);

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