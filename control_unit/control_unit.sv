module control_unit(
    input logic[31:0] ins1,
    output logic alu_src,
    output logic mem_read,
    output logic mem_write,
    output logic reg_write,
    output logic branch,
    output logic[1:0] mem_to_reg,
    output logic jump,
    output logic[3:0] alu_op,
    output logic jalr
);

logic[6:0] opcode;
logic[2:0] funct3;
logic[6:0] funct7;

assign opcode=ins1[6:0];
assign funct3=ins1[14:12];
assign funct7=ins1[31:25];

always_comb begin
    alu_src=1'b0; // alu_src is 1 if second operand in the ALU is immediate
    mem_read=1'b0;
    mem_write=1'b0;
    mem_to_reg=1'b0;
    reg_write=1'b0;
    branch=1'b0;
    alu_op=4'b0000;
    jump=1'b0;
    jalr=1'b0;

    case(opcode)
    7'b0110011: begin
        alu_src=1'b0; 
        reg_write=1'b1;

        case({funct7,funct3})
          10'b0000000_000: alu_op = 4'b0000;  // ADD
          10'b0100000_000: alu_op = 4'b0001;  // SUB
          10'b0000000_111: alu_op = 4'b0010;  // AND
          10'b0000000_110: alu_op = 4'b0011;  // OR
          10'b0000000_100: alu_op = 4'b0100;  // XOR
          10'b0000000_001: alu_op = 4'b0101;  // SLL
          10'b0000000_101: alu_op = 4'b0110;  // SRL
          10'b0100000_101: alu_op = 4'b0111;  // SRA
          10'b0000000_010: alu_op = 4'b1000;  // SLT
           10'b0000000_011: alu_op = 4'b1001;  // SLTU
        default:          alu_op = 4'b0000;
    endcase
    end
    7'b1100111: begin
        alu_src=1'b1;
        reg_write=1'b1;
        mem_to_reg=2'b10;
        alu_op=4'b0000;
        jalr=1'b1;
    end


    7'b0010011: begin
        alu_src=1'b1;
        reg_write=1'b1;
        mem_to_reg=2'b00;
        case (funct3)
        3'b000: alu_op = 4'b0000;  // ADDI
        3'b111: alu_op = 4'b0010;  // ANDI
        3'b110: alu_op = 4'b0011;  // ORI
        3'b100: alu_op = 4'b0100;  // XORI
        default: alu_op = 4'b0000;
    endcase
    end
    
    7'b0000011: begin //LW for loading the value to register 
        alu_src=1'b1;
        mem_read=1'b1;
        mem_to_reg=2'b01;
        reg_write=1'b1;
        alu_op=4'b0000;
    end
    7'b0100011: begin //SW type for writing to memory
        alu_src=1'b1;
        mem_write=1'b1;
        alu_op=4'b0000;
    end
    7'b1100011: begin
        branch=1'b1;
        alu_op=4'b0001;
    end
    7'b1101111: begin
        mem_to_reg=2'b10;
        reg_write=1'b1;
        jump=1'b1;
        
    end

    endcase
end
endmodule



