module imm_gen_tb();

logic [31:0] ins1;
logic[31:0] immediate;
int errors = 0;

imm_gen dut(
    .ins1(ins1), 
    .immediate(immediate)
);

initial begin
    $dumpfile("imm_gen_tb.vcd");
    $dumpvars(0, imm_gen_tb);
end

task check(input string name, input [31:0] instr, input [31:0] exp);
begin
    ins1 = instr;
    #1;
    if (immediate !== exp) begin
        errors++;
        $display("FAIL: %s expected %0d got %0d", name, $signed(exp), $signed(immediate));
    end
end
endtask

initial begin
    check("ADDI -1",   32'hFFF00093, -32'sd1);
    check("LW 8",      32'h00812083,  32'd8);
    check("SW -4",     32'hFE20AE23, -32'sd4);
    check("SW 12",     32'h0020A623,  32'd12);
    check("BEQ -8",    32'hFE220CE3, -32'sd8);
    check("BEQ 2050",  32'h002201E3,  32'd2050);
    check("JAL -4",    32'hFFDFF0EF, -32'sd4); //'sd4 is the signed number and it represents -4 we can also write this as 32'hFFFFFFFC
    check("JAL 2048",  32'h001000EF,  32'd2048);
    check("JAL 4096",  32'h000010EF,  32'd4096);
    check("R-type",    32'h002081B3,  32'd0);

    if (errors == 0) begin
        $display("imm_gen: ALL CHECKS PASSED");
    end
    else begin
        $display("imm_gen: %0d FAILED", errors);
    end
    #2;
    $finish;
end

endmodule
