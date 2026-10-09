module control_unit_tb();

logic[31:0] ins1;
logic alu_src;
logic mem_read;
logic mem_write;
logic reg_write;
logic branch;
logic[1:0] mem_to_reg;
logic jump;
logic[3:0] alu_op;
logic jalr;

control_unit dut(
    .ins1(ins1),
    .alu_src(alu_src),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .reg_write(reg_write),
    .branch(branch),
    .mem_to_reg(mem_to_reg),
    .jump(jump),
    .alu_op(alu_op),
    .jalr(jalr)

);

initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0,control_unit_tb);
    
end


int errors=0;

// order: {alu_src, mem_read, mem_write, reg_write, branch, jump, jalr, mem_to_reg[1:0], alu_op[3:0]}  -> 13 bits
task check_control(input string name ,input logic [12:0] exp);
    logic [12:0] got;
    begin
        got = {alu_src, mem_read, mem_write, reg_write, branch, jump, jalr, mem_to_reg, alu_op};
        if (got === exp) begin
             $display("PASS %s", name);
        end
        else begin
            $display("FAIL %s  got=%b  exp=%b", name, got, exp);
            errors++;
        end
    end
endtask



initial begin
    #2;
    ins1 = 32'h002081B3;
    #2;
    check_control("ADD",13'b0001000000000); //USING UNDERSCORE IS OPTIONAL..BOTH OF THEM WILL COMPILE..USING UNDERSCORE HELPS US TO IDENTIFY EACH VARIABLE IN THE 13BIT CONCATENTATION.
    #2;
    ins1 = 32'h402081B3; 
    #2;
    check_control("SUB",  13'b0_0_0_1_0_0_0_00_0001);

    ins1 = 32'h0020F1B3; 
    #2;
    check_control("AND",  13'b0_0_0_1_0_0_0_00_0010);

    ins1 = 32'h0020E1B3; 
    #2;
    check_control("OR",   13'b0_0_0_1_0_0_0_00_0011);

    ins1 = 32'h0020C1B3; 
    #2;
    check_control("XOR",  13'b0_0_0_1_0_0_0_00_0100);

    ins1 = 32'h00500093; 
    #2;
    check_control("ADDI", 13'b1_0_0_1_0_0_0_00_0000);

    ins1 = 32'h00002203; 
    #2;
    check_control("LW",   13'b1_1_0_1_0_0_0_01_0000);

    ins1 = 32'h00202023; 
    #2;
    check_control("SW",   13'b1_0_1_0_0_0_0_00_0000);

    ins1 = 32'h00410463; 
    #2;
    check_control("BEQ",  13'b0_0_0_0_1_0_0_00_0001);

    ins1 = 32'h008003EF; 
    #2;
    check_control("JAL",  13'b0_0_0_1_0_1_0_10_0000);

    ins1 = 32'h008304E7; 
    #2;
    check_control("JALR", 13'b1_0_0_1_0_0_1_10_0000);

    ins1 = 32'hFFFFFFFF; 
    #2;
    check_control("ILLEGAL", 13'b0_0_0_0_0_0_0_00_0000);
    #2;

    $display("errors = %0d", errors);
    #2;
    $finish;
    
end

endmodule

    