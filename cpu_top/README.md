# cpu_top - full CPU integration test

Top level of the RV32I single-cycle core. It wires every submodule together and runs a 23-instruction program, checking the PC and a register (or memory) after every instruction. Simulated in Vivado (xsim) with `cpu_top_tbn` as the simulation top.

## Datapath

```
pc_top --> instr_mem --> control_unit
                     |-> imm_gen
                     |-> register (read ports)

register --> alu_operand --> alu --> data_mem --> wbmux --> register (write back)
alu result --> pc_top (JALR target)
branch_addr / jump_addr --> pc_top (BEQ and JAL targets)
```

The PC is a byte address. Instructions are 4 bytes, so the instruction memory is read with `pc[9:2]`.

## Where each module lives

| Module | Folder | Tested on its own? |
|---|---|---|
| alu | `alu/` | yes |
| imm_gen | `imm_gen/` | yes |
| register | `register/` | yes |
| control_unit | `control_unit/` | yes |
| data_mem | `data_mem/` | yes |
| pc_top (+ programcounter, pc_adder, branch_addr, jump_addr, as instantiated) | `pc_top/` | yes, as one unit |
| instr_mem, alu_operand, wbmux | `cpu_top/rtl/` | no, only through this CPU test |
| cpu_top | `cpu_top/` | this folder |

## Supported instructions

R-type (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU), I-type (ADDI, ANDI, ORI, XORI, LW, JALR), S-type (SW), B-type (BEQ only) and J-type (JAL).

## How the test works

- Before reset ends, the testbench clears all 256 instruction words and all 32 registers (so nothing is X), then loads the program straight into `instr_mem` with hierarchical references.
- Reset is held for three clock edges, then released.
- `check(name, reg, expected)` waits for the next posedge plus 2 time units, then reads the register file. `check_pc(expected)` then reads the PC 2 time units later.
- One check pair per instruction, so the checks follow the program step by step. After each instruction the PC already points to the next one.
- SW is also checked directly in data memory with an immediate assert, because it is the only instruction that writes there.
- Failures increment an error counter; the run ends with a PASS / FAIL summary.

## Test program

| PC | Instruction | Expected |
|---|---|---|
| 0 | addi x1,x0,12 | x1 = 12 |
| 4 | addi x2,x0,10 | x2 = 10 |
| 8 | add x3,x1,x2 | x3 = 22 |
| 12 | sub x4,x1,x2 | x4 = 2 |
| 16 | and x5,x1,x2 | x5 = 8 |
| 20 | or x6,x1,x2 | x6 = 14 |
| 24 | xor x7,x1,x2 | x7 = 6 |
| 28 | addi x10,x0,-16 | x10 = 0xFFFFFFF0 |
| 32 | slt x12,x10,x1 | x12 = 1 (signed: -16 < 12) |
| 36 | sltu x13,x10,x1 | x13 = 0 (unsigned: 0xFFFFFFF0 > 12) |
| 40 | sw x3,16(x0) | mem[4] = 22 |
| 44 | lw x14,16(x0) | x14 = 22 |
| 48 | beq x3,x14,+8 | taken, PC goes to 56, x15 stays 0 |
| 52 | addi x15,x0,99 | skipped |
| 56 | beq x1,x2,+8 | not taken, PC goes to 60 |
| 60 | addi x16,x0,1 | x16 = 1 |
| 64 | jal x17,+8 | x17 = 68, PC goes to 72 |
| 68 | addi x18,x0,99 | skipped, x18 stays 0 |
| 72 | addi x19,x0,84 | x19 = 84 |
| 76 | jalr x20,0(x19) | x20 = 80, PC goes to 84 |
| 80 | addi x21,x0,99 | skipped, x21 stays 0 |
| 84 | addi x22,x0,7 | x22 = 7 |
| 88 | beq x0,x0,0 | halt loop, PC stays at 88 |

In total: 21 register checks, 22 PC checks and 1 data-memory assert.

## Result

![Tcl console](result.png)
![Waveform](waveform.png)

Every check passes and the PC ends in the halt loop at 88. The testbench checks the registers themselves.

## What is and is not tested

- This is one fixed program. It exercises ADDI, ADD, SUB, AND, OR, XOR, SLT, SLTU, SW, LW, BEQ (taken and not taken), JAL and JALR once each.
- SLL/SRL/SRA are implemented in the ALU but this program does not run them through the CPU.
- I-type shifts (SLLI, SRLI, SRAI) and SLTI/SLTIU are not decoded by the control unit.
- ANDI, ORI and XORI are not in this program.
- Only BEQ is implemented. BNE, BLT, BGE and the unsigned branches are not supported.
- JALR clears bit 0 of the target, as the RISC-V spec requires. Bit 1 is not checked, so a target that is not a multiple of 4 would not trap.
- Data memory is 256 words (1 KB) and the address wraps. There are no byte or halfword accesses.
- instr_mem, alu_operand and wbmux have no standalone testbenches.
- Simulation only (Vivado xsim). Not synthesised and not tested on an FPGA.
