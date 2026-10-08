module alu_tb();

logic[31:0] operand_a;
logic[31:0] operand_b;
logic[31:0] result;
logic[3:0] alu_op;
logic zero;

alu dut(
    .operand_a(operand_a),
    .operand_b(operand_b),
    .result(result),
    .alu_op(alu_op),
    .zero(zero)

);

initial begin
    $dumpfile("alu_tb.vcd");
    $dumpvars(0, alu_tb);
end

int errors=0;

task check(input string name,input [31:0] exp_result,input exp_zero); begin
    if(result!==exp_result || zero!==exp_zero) begin
        errors++;
        $display("FAIL: %s EXPECTED RESULT %0d but got %0d",name,exp_result,result);
    end
    else begin
        $display("%s PASSED",name);
    end
end
endtask

        




initial begin
    operand_a=32'd10;
    operand_b=32'd20;
    alu_op=4'b0000;
    #10;
    check("ADD",32'd30,1'b0);
    #10;
    operand_a=32'd2;
    operand_b=32'd2;
    alu_op=4'b0001;
    #10;
    check("SUB",32'd0,1'b1);
    #10;
    operand_a=32'hffffffff;
    operand_b=32'd1;
    alu_op=4'b1000;
    #10;
    check("SLT",32'd1,1'b0);
    #10;
    operand_a=32'hffffffff;
    operand_b=32'd1;
    alu_op=4'b1001;
    #10;
    check("SLTU",32'd0,1'b1);

    #10;
    if(errors==1'b0) begin
        $display("ALL CHECKS PASSED");
    end
    else begin
        $display("FAIL ERROR(s) %0d",errors);
    end
    $finish;

end

endmodule