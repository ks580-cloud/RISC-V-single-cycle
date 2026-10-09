module register_tb();

logic clk = 0, reset = 0, write_enable = 0;
logic [4:0]  rs1_addr, rs2_addr, rd_addr;
logic [31:0] rd_data, rs1_data, rs2_data;
int errors = 0;

register dut(.clk(clk), .reset(reset), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
             .rd_addr(rd_addr), .rd_data(rd_data), .write_enable(write_enable),
             .rs1_data(rs1_data), .rs2_data(rs2_data));

always #5 clk = ~clk;

initial begin
    $dumpfile("register_tb.vcd");
    $dumpvars(0, register_tb);
end

// drive before the edge, release just after it
task write(input [4:0] r, input [31:0] d);
begin
    rd_addr = r; rd_data = d; write_enable = 1;
    @(posedge clk); #1;
    write_enable = 0;
end
endtask

task check(input string name, input [31:0] actual, input [31:0] exp);
begin
    if (actual !== exp) begin
        errors++;
        $display("FAIL: %s expected %0d got %0d", name, exp, actual);
    end
end
endtask

initial begin
    write(1, 32'd10);
    write(2, 32'd20);
    rs1_addr = 1; rs2_addr = 2; #1;
    check("write/read x1", rs1_data, 32'd10);
    check("write/read x2", rs2_data, 32'd20);

    write(0, 32'd99);
    rs1_addr = 0; #1;
    check("x0 stays 0", rs1_data, 32'd0);

    write(3, 32'd5);
    rd_addr = 3; rd_data = 32'd77;            // write_enable is 0
    @(posedge clk); #1;
    rs1_addr = 3; #1;
    check("no write when disabled", rs1_data, 32'd5);

    write(4, 32'd8);
    reset = 1;
    write(4, 32'd6);                          // ignored during reset
    reset = 0;
    rs1_addr = 4; #1;
    check("write ignored in reset", rs1_data, 32'd8);

    if (errors == 0) $display("register: ALL CHECKS PASSED");
    else             $display("register: %0d FAILED", errors);
    $finish;
end

endmodule