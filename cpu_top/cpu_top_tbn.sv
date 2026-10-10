module cpu_top_tbn();

logic clk;
logic reset;

cpu_top dut(
    .clk(clk),
    .reset(reset)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end





int i;
int errors;

task check_pc(input logic[31:0] exp_pc); begin
    #2;
    if(exp_pc === dut.pc) begin
        $display("PC: %0d",dut.pc);
    end
    else begin
        errors++;
        $display("FAIL: expected PC =%0d but actual=%0d",exp_pc,dut.pc);
end
end

endtask

logic[31:0] actual_reg;

task check(input string name,input logic[4:0] actual_address,input logic[31:0] expected); begin
    @(posedge clk);
    #2;
    actual_reg=dut.dut5.regfile[actual_address];
    if(actual_reg !== expected ) begin
        $display("FAIL: %s expected register %0d value=%0d..but got %0d",name,actual_address,expected,actual_reg);
        errors++;
    end
    else begin
        $display("STATUS FOR %s: PASSED",name);
end


end
endtask




initial begin
    reset=1'b1;

    // clear both memories first, so unused locations are 0 and not X
    for(i=0;i<256;i=i+1) begin
        dut.dut2.insmem[i]=32'd0;
    end
    for(i=0;i<32;i=i+1) begin
       dut.dut5.regfile[i]=32'd0;
    end
    #2;
    dut.dut2.insmem[0]=32'h00C00093;   // addi x1,x0,12
    dut.dut2.insmem[1]=32'h00A00113;   // addi x2,x0,10
    dut.dut2.insmem[2]=32'h002081B3;   // add  x3,x1,x2
    dut.dut2.insmem[3]=32'h40208233;   // sub  x4,x1,x2
    dut.dut2.insmem[4]=32'h0020F2B3;   // and  x5,x1,x2
    dut.dut2.insmem[5]=32'h0020E333;   // or   x6,x1,x2
    dut.dut2.insmem[6]=32'h0020C3B3;   // xor  x7,x1,x2
    dut.dut2.insmem[7]=32'hFF000513;   // addi x10,x0,-16
    dut.dut2.insmem[8]=32'h00152633;   // slt  x12,x10,x1
    dut.dut2.insmem[9]=32'h001536B3;   // sltu x13,x10,x1
    dut.dut2.insmem[10]=32'h00302823;  // sw   x3,16(x0)
    dut.dut2.insmem[11]=32'h01002703;  // lw   x14,16(x0)
    dut.dut2.insmem[12]=32'h00E18463;  // beq  x3,x14,+8   (taken)
    dut.dut2.insmem[13]=32'h06300793;  // addi x15,x0,99   (skipped)
    dut.dut2.insmem[14]=32'h00208463;  // beq  x1,x2,+8    (not taken)
    dut.dut2.insmem[15]=32'h00100813;  // addi x16,x0,1
    dut.dut2.insmem[16]=32'h008008EF;  // jal  x17,+8
    dut.dut2.insmem[17]=32'h06300913;  // addi x18,x0,99   (skipped)
    dut.dut2.insmem[18]=32'h05400993;  // addi x19,x0,84
    dut.dut2.insmem[19]=32'h00098A67;  // jalr x20,0(x19)
    dut.dut2.insmem[20]=32'h06300A93;  // addi x21,x0,99   (skipped)
    dut.dut2.insmem[21]=32'h00700B13;  // addi x22,x0,7
    dut.dut2.insmem[22]=32'h00000063;  // beq  x0,x0,0     (halt)
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    check_pc(32'd0);
    reset=1'b0;
    check("ADDI x1",5'd1,32'd12);
    check_pc(32'd4);
    check("ADDI x2",5'd2,32'd10);
    check_pc(32'd8);
    check("ADD x3",5'd3,32'd22);
    check_pc(32'd12);
    check("SUB x4",5'd4,32'd2);
    check_pc(32'd16);
    check("AND x5",5'd5,32'd8);
    check_pc(32'd20);
    check("OR x6",5'd6,32'd14);
    check_pc(32'd24);
    check("XOR x7",5'd7,32'd6);
    check_pc(32'd28);
    check("ADDI x10",5'd10,32'hFFFFFFF0);
    check_pc(32'd32);
    check("SLT x12",5'd12,32'd1);
    check_pc(32'd36);
    check("SLTU x13",5'd13,32'd0);
    check_pc(32'd40);
    check("SW leaves x3",5'd3,32'd22);
    assert(dut.dut8.datamem[4] === 32'd22) $display("SW writes mem[4]: PASSED"); /* Immediate ASSERT to check the data_mem as SW writes to data memory so its 
    worth checking the data memory using an immedate assert */
    else begin
    $display("FAIL: SW expected datamem[4]=22 but got %0d",dut.dut8.datamem[4]);
    errors++;
    end
    check_pc(32'd44);
    check("LW x14",5'd14,32'd22);
    check_pc(32'd48);
    check("BEQ taken, x15 untouched",5'd15,32'd0);
    check_pc(32'd56);
    check("BEQ not taken, x15 untouched",5'd15,32'd0);
    check_pc(32'd60);
    check("ADDI x16",5'd16,32'd1);
    check_pc(32'd64);
    check("JAL link x17",5'd17,32'd68);
    check_pc(32'd72);
    check("ADDI x19",5'd19,32'd84);
    check_pc(32'd76);
    check("JALR link x20",5'd20,32'd80);
    check_pc(32'd84);
    check("ADDI x22",5'd22,32'd7);
    check_pc(32'd88);
    check("halt, x18 skipped",5'd18,32'd0);
    check_pc(32'd88);
    check("halt, x21 skipped",5'd21,32'd0);
    check_pc(32'd88);
    #2;
    if(errors) begin
        $display("OPERATION FAILED WITH ERROR(s) %0d",errors);
    end
    else begin
        $display("RISC V SINGLE CYCLE OPERATION SUCCESFULLY PASSED");
    end
    #2;
    $finish;
end

endmodule



    