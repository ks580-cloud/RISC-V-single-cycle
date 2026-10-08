module imm_gen(
    input logic[31:0] ins1,
    output logic[31:0] immediate
);

logic[6:0] opcode;
assign opcode=ins1[6:0];

always_comb begin
    case(opcode)
    7'b0010011,7'b0000011,7'b1100111: begin
        immediate={{20{ins1[31]}},ins1[31:20]};
    end
    7'b0100011: begin
        immediate={{20{ins1[31]}},ins1[31:25],ins1[11:7]};
    end
    7'b1100011:begin
        immediate={{19{ins1[31]}},ins1[31],ins1[7],ins1[30:25],ins1[11:8],1'b0};
    end
    7'b1101111:begin
        immediate={{11{ins1[31]}},ins1[31],ins1[19:12],ins1[20],ins1[30:21],1'b0};
    end
    default: begin
        immediate=32'd0;
    end
endcase
end
endmodule

