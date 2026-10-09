# Control Unit (`control_unit`)

Part of a single-cycle RV32I CPU written in SystemVerilog.

**Supported instructions (the only ones documented and tested here):** ADD, SUB, ADDI, AND, OR, XOR, LW, SW, BEQ, JAL, JALR. One extra case is tested: an illegal instruction (`32'hFFFFFFFF`), which must give all-zero outputs.

**Files this README describes:** `control_unit.sv` (the RTL) and `control_unit_tb.sv` (the testbench). Neither file was modified while writing this document.

---

## 1. What this module is

A single-cycle CPU runs one whole instruction per clock cycle. Every part of the CPU (register file, ALU, data memory, ...) is used in that one cycle, but each instruction needs the parts set up differently. For example:

- `add` must read two registers, use the ALU, and write a register.
- `sw` must use the ALU to compute an address and write memory, but must **not** write a register.
- `beq` must compare two registers and possibly change the PC.

The **control unit** reads the 32-bit instruction and produces a handful of 1-bit and few-bit **control signals** that set switches (multiplexers, enables) in the other modules. It does not touch data itself. It only decides what the other modules should do.

**Why it is purely combinational:** the control signals depend only on the instruction bits that are currently on the input. There is no memory inside it and no clock. As soon as `ins1` changes, the outputs change. The instruction itself is held steady for the whole cycle (it comes from instruction memory addressed by the PC), so the control signals are stable for the whole cycle too.

```
                             +----------------+
                             |                |--- alu_src ----------> ALU operand mux (picks rs2 or immediate)
                             |                |--- alu_op[3:0] ------> ALU (which operation)
                             |                |--- reg_write --------> Register file (write enable)
   instruction  ins1[31:0]   |  control_unit  |--- mem_read ---------> Data memory
  ---------------------------> (combinational)|--- mem_write --------> Data memory
   (from instruction memory) |                |--- mem_to_reg[1:0] --> Write-back mux (what goes into rd)
                             |                |--- branch -----------> PC logic (branch_taken = branch & zero)
                             |                |--- jump -------------> PC logic (JAL)
                             |                |--- jalr -------------> PC logic (JALR)
                             +----------------+
```

This wiring comes from `cpu_top.sv`, `pc_top.sv` and `wbmux.sv` in the same project. The ALU's `zero` flag goes to the PC logic, not to the control unit.

---

## 2. Ports

| Name | Direction | Width | Meaning |
|---|---|---|---|
| `ins1` | input | 32 | The full instruction word |
| `alu_src` | output | 1 | Chooses the ALU's second operand: `0` = register `rs2`, `1` = the immediate |
| `mem_read` | output | 1 | `1` = data memory is read (LW) |
| `mem_write` | output | 1 | `1` = data memory is written (SW) |
| `reg_write` | output | 1 | `1` = the register file writes `rd_data` into register `rd` at the clock edge |
| `branch` | output | 1 | `1` = this is a branch instruction (BEQ). The PC logic uses `branch & zero` |
| `mem_to_reg` | output | 2 | Chooses what is written into `rd`: `00` = ALU result, `01` = data from memory, `10` = PC + 4 |
| `jump` | output | 1 | `1` = JAL. The PC logic takes the jump target (PC + immediate) |
| `alu_op` | output | 4 | ALU operation: `0000` ADD, `0001` SUB, `0010` AND, `0011` OR, `0100` XOR (as defined by this project's `alu.sv`) |
| `jalr` | output | 1 | `1` = JALR. The PC logic takes the ALU result (`rs1 + immediate`) as the next PC |

---

## 3. How decoding works

### Extracting the fields

RISC-V keeps the same fields in the same bit positions in every instruction, so the control unit can slice them out directly:

```systemverilog
assign opcode = ins1[6:0];     // what kind of instruction
assign funct3 = ins1[14:12];   // sub-type within a kind
assign funct7 = ins1[31:25];   // second sub-type (needed for ADD vs SUB)
```

### Why R-type needs `funct7` and `funct3`, but LW, SW, BEQ, JAL, JALR need only the opcode

- **R-type** (ADD, SUB, AND, OR, XOR) all share **one opcode**, `0110011`. The opcode only says "do an ALU operation on two registers". To know which operation, the unit must look at `funct3` (for example `000` = ADD/SUB, `111` = AND, `110` = OR, `100` = XOR) and at `funct7` (for `funct3 = 000`: `0000000` = ADD, `0100000` = SUB). That is why the R-type branch has a second `case` on `{funct7, funct3}`.
- **LW, SW, BEQ, JAL, JALR** each have their **own opcode** (`0000011`, `0100011`, `1100011`, `1101111`, `1100111`). Within this instruction set, the opcode alone identifies the instruction, so `funct3` and `funct7` are not looked at.
- **ADDI** has its own opcode (`0010011`), but the RTL still checks `funct3` so that different immediate ALU operations pick different `alu_op` values. Only `funct3 = 000` (ADDI) is tested here.

### Why the defaults at the top of the `always_comb` block prevent latches

A **latch** is a memory element that synthesis creates when a combinational block does not assign an output on every possible path. If an output is left unassigned on some path, hardware has to "remember" its old value, which is a latch, and it is almost always a bug.

The RTL assigns **every output a default value on the first lines** of the block (`alu_src = 0`, `mem_read = 0`, ..., `alu_op = 0000`). The `case` statements below only override the signals that differ for that instruction. This means:

- every output has a value for every possible `ins1`, including ones that match no case,
- the outer `case(opcode)` does not need a `default:` branch, because the defaults at the top already cover it,
- no latch can be inferred.

One cosmetic detail: `mem_to_reg = 1'b0;` assigns a 1-bit literal to a 2-bit output. It is zero-extended to `2'b00`, so the result is correct.

---

## 4. Instruction encodings

Hex values are the ones used in the testbench. The binary is split into the labelled fields of each format. The field layouts come from the RISC-V spec.

Register numbers are written as `xN`. Instruction formats: R = register-register, I = immediate, S = store, B = branch, J = jump.

| Instruction | Hex | Meaning |
|---|---|---|
| ADD | `0x002081B3` | `add x3, x1, x2` : x3 = x1 + x2 |
| SUB | `0x402081B3` | `sub x3, x1, x2` : x3 = x1 - x2 |
| AND | `0x0020F1B3` | `and x3, x1, x2` : x3 = x1 & x2 |
| OR | `0x0020E1B3` | `or x3, x1, x2` : x3 = x1 \| x2 |
| XOR | `0x0020C1B3` | `xor x3, x1, x2` : x3 = x1 ^ x2 |
| ADDI | `0x00500093` | `addi x1, x0, 5` : x1 = x0 + 5 (x0 is always 0, so x1 = 5) |
| LW | `0x00002203` | `lw x4, 0(x0)` : x4 = memory[x0 + 0] |
| SW | `0x00202023` | `sw x2, 0(x0)` : memory[x0 + 0] = x2 |
| BEQ | `0x00410463` | `beq x2, x4, 8` : if x2 == x4, PC = PC + 8 |
| JAL | `0x008003EF` | `jal x7, 8` : x7 = PC + 4, PC = PC + 8 |
| JALR | `0x008304E7` | `jalr x9, 8(x6)` : x9 = PC + 4, PC = x6 + 8 |

### R-type: `funct7 | rs2 | rs1 | funct3 | rd | opcode`

| Instr | funct7 (7) | rs2 (5) | rs1 (5) | funct3 (3) | rd (5) | opcode (7) |
|---|---|---|---|---|---|---|
| ADD `002081B3` | `0000000` | `00010` (x2) | `00001` (x1) | `000` | `00011` (x3) | `0110011` |
| SUB `402081B3` | `0100000` | `00010` (x2) | `00001` (x1) | `000` | `00011` (x3) | `0110011` |
| AND `0020F1B3` | `0000000` | `00010` (x2) | `00001` (x1) | `111` | `00011` (x3) | `0110011` |
| OR `0020E1B3` | `0000000` | `00010` (x2) | `00001` (x1) | `110` | `00011` (x3) | `0110011` |
| XOR `0020C1B3` | `0000000` | `00010` (x2) | `00001` (x1) | `100` | `00011` (x3) | `0110011` |

ADD and SUB differ only in `funct7` (bit 30 is `1` for SUB).

### I-type: `imm[11:0] | rs1 | funct3 | rd | opcode`

| Instr | imm[11:0] (12) | rs1 (5) | funct3 (3) | rd (5) | opcode (7) |
|---|---|---|---|---|---|
| ADDI `00500093` | `000000000101` (5) | `00000` (x0) | `000` | `00001` (x1) | `0010011` |
| LW `00002203` | `000000000000` (0) | `00000` (x0) | `010` | `00100` (x4) | `0000011` |
| JALR `008304E7` | `000000001000` (8) | `00110` (x6) | `000` | `01001` (x9) | `1100111` |

LW and JALR use the I-type layout too: the 12-bit immediate is the address offset.

### S-type: `imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode`

| Instr | imm[11:5] (7) | rs2 (5) | rs1 (5) | funct3 (3) | imm[4:0] (5) | opcode (7) |
|---|---|---|---|---|---|---|
| SW `00202023` | `0000000` | `00010` (x2) | `00000` (x0) | `010` | `00000` | `0100011` |

Immediate = `{imm[11:5], imm[4:0]}` = 0. A store has no `rd`: that field is used for part of the immediate.

### B-type: `imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode`

| Instr | imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode |
|---|---|---|---|---|---|---|---|---|
| BEQ `00410463` | `0` | `000000` | `00100` (x4) | `00010` (x2) | `000` | `0100` | `0` | `1100011` |

Immediate = `{imm[12], imm[11], imm[10:5], imm[4:1], 0}` = `0 0 000000 0100 0` = 8. The lowest bit is always 0 (branch offsets are even and not stored).

### J-type: `imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode`

| Instr | imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode |
|---|---|---|---|---|---|---|
| JAL `008003EF` | `0` | `0000000100` | `0` | `00000000` | `00111` (x7) | `1101111` |

Immediate = 8 (imm[10:1] = `0000000100` = 4, shifted left by 1 because bit 0 is implied 0).

### Illegal

`0xFFFFFFFF` has opcode `1111111`, which is not any supported opcode.

---

## 5. Control signal table

`x` means the value does not matter for that instruction. In the RTL it stays at the default (`0`).

| Instr | alu_src | mem_read | mem_write | reg_write | branch | jump | jalr | mem_to_reg | alu_op | WHY |
|---|---|---|---|---|---|---|---|---|---|---|
| ADD | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0000 (ADD) | Two register operands (`alu_src=0`). Result goes to `rd` (`reg_write=1`, `mem_to_reg=00` = ALU result). No memory, no PC change |
| SUB | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0001 (SUB) | Same as ADD, but the ALU subtracts (`funct7[5]=1`) |
| AND | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0010 (AND) | Same as ADD with a bitwise AND (`funct3=111`) |
| OR | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0011 (OR) | Same as ADD with a bitwise OR (`funct3=110`) |
| XOR | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0100 (XOR) | Same as ADD with a bitwise XOR (`funct3=100`) |
| ADDI | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 00 | 0000 (ADD) | Second operand is the immediate (`alu_src=1`), ALU adds `rs1 + imm`, result is written to `rd` |
| LW | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 01 | 0000 (ADD) | ALU computes the **address** `rs1 + imm` (`alu_src=1`, ADD). Memory is read (`mem_read=1`). The loaded data (`mem_to_reg=01`) goes into `rd` (`reg_write=1`) |
| SW | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 00 | 0000 (ADD) | ALU computes the **address** `rs1 + imm`. Memory is written (`mem_write=1`) with `rs2`. A store produces no result for a register, so `reg_write=0`. `mem_to_reg` does not matter |
| BEQ | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 00 | 0001 (SUB) | ALU compares the two registers (`alu_src=0`) by subtracting `rs1 - rs2`. `branch=1`. No register is written |
| JAL | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 10 | 0000 (default) | Writes the link address PC + 4 to `rd` (`reg_write=1`, `mem_to_reg=10`). `jump=1` makes the PC logic take PC + immediate. The ALU is not needed for this instruction |
| JALR | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 10 | 0000 (ADD) | ALU computes the jump target `rs1 + imm` (`alu_src=1`, ADD). `jalr=1` makes the PC logic take the ALU result as the next PC. Writes PC + 4 to `rd` (`mem_to_reg=10`) |
| ILLEGAL | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 00 | 0000 | No case matches, so every output keeps its default. Nothing is written, nothing branches |

### Explaining the specific choices

- **Why SW has `reg_write = 0`.** A store copies a register into memory. It has no destination register, so nothing may be written to the register file. If `reg_write` were 1, the store would overwrite some register with garbage (the bits that normally hold `rd` hold part of the immediate in a store).
- **Why LW, SW and JALR use `alu_op = ADD` with `alu_src = 1`.** All three need `rs1 + immediate`:
  - LW: the **address** to load from,
  - SW: the **address** to store to,
  - JALR: the **jump target**.

  `alu_src = 1` feeds the immediate to the ALU's second input, and ADD adds it to `rs1`.
- **Why BEQ uses SUB, and how `branch_taken = branch & zero` uses the result.** `rs1 - rs2` is zero exactly when the two registers are equal. The ALU's `zero` flag is `1` when its result is 0. In `pc_top.sv`, `branch_taken = branch & zero`. So the branch is taken only when it is a branch instruction **and** the operands are equal. The ALU result itself is not used. Only the `zero` flag matters. If `branch_taken` is 1, the next PC is the branch target (PC + immediate).
- **Why JAL leaves `alu_op` at the default.** JAL's target is PC + immediate, computed by a separate adder in the PC logic (`jump_addr`), not by the ALU. The ALU still produces some value for JAL, but nothing uses it (`mem_to_reg = 10` selects PC + 4, memory is idle). So the control unit does not set `alu_op`, and it stays `0000`.
- **Why JAL has `alu_src = 0` and JALR has `alu_src = 1`.** JAL does not use the ALU, so `alu_src` is left at its default `0`. JALR does use the ALU, to compute `rs1 + immediate`, so it needs the immediate as the second operand: `alu_src = 1`.
- **Why JAL and JALR use `mem_to_reg = 10`.** Both instructions save a **return (link) address** in `rd` so that the program can come back later. That address is the address of the next instruction, PC + 4. `mem_to_reg = 10` tells the write-back mux to pass PC + 4 to `rd`, instead of the ALU result (`00`) or the loaded data (`01`).

PC priority in `pc_top.sv`: `branch_taken` first, then `jump`, then `jalr`, otherwise PC + 4.

---

## 6. The testbench

`control_unit_tb.sv` applies one instruction at a time and compares all control outputs against an expected value in a single comparison.

**Structure (line numbers refer to `control_unit_tb.sv`)**

- **Lines 3-12:** declare `ins1` (driven by the testbench) and one signal for every control output.
- **Lines 14-26:** instantiate the control unit (`dut`) and connect every port by name.
- **Lines 28-32:** `$dumpfile("tb.vcd")` and `$dumpvars` write a waveform file `tb.vcd`. They were already in the testbench. Running it creates `tb.vcd` in the current folder.
- **Line 35:** `int errors = 0;` counts failures.
- **Lines 37-50:** the `check_control` task (explained below).
- **Lines 54-109:** the stimulus. For each instruction: drive `ins1`, wait `#2`, call `check_control` with the name and the expected value.
- **Lines 105-107:** print `errors = N` and finish.

### The 13-bit packed expected vector

All 9 outputs are packed into one 13-bit vector, so one comparison checks everything:

```
{ alu_src, mem_read, mem_write, reg_write, branch, jump, jalr, mem_to_reg[1:0], alu_op[3:0] }
   1 bit     1 bit      1 bit      1 bit     1 bit  1 bit 1 bit      2 bits          4 bits      = 13 bits
```

Example, JAL: `13'b0_0_0_1_0_1_0_10_0000`: alu_src=0, mem_read=0, mem_write=0, reg_write=1, branch=0, jump=1, jalr=0, mem_to_reg=10, alu_op=0000.

The underscores are optional in Verilog. They are there only to make the groups easy to read. The first test (ADD) is written without underscores (`13'b0001000000000`), which is the same value.

### How the `check_control` task works

```systemverilog
task check_control(input string name, input logic [12:0] exp);
    logic [12:0] got;
    begin
        got = {alu_src, mem_read, mem_write, reg_write, branch, jump, jalr, mem_to_reg, alu_op};
        if (got === exp) $display("PASS %s", name);
        else begin $display("FAIL %s  got=%b  exp=%b", name, got, exp); errors++; end
    end
endtask
```

1. It builds `got` by concatenating the real outputs, in the **same order** as the expected vector.
2. It compares `got` to `exp`.
3. It prints PASS or FAIL (with both values in binary) and counts the failures.

### Why `===` and not `==`

`==` can return `X` (unknown) if either side contains an `X` bit, and an `if` on `X` is treated as false. So with `==`, a test that has `X` in the outputs could silently take the wrong branch. `===` compares the four-state values exactly (0, 1, X, Z must match bit for bit) and always gives 0 or 1. So an output stuck at `X` is reported as a mismatch.

### Why there is a `#2` after driving `ins1`

The control unit is an `always_comb` block. When `ins1` changes, the simulator re-evaluates the block a moment later, not at the same instant the testbench assigned `ins1`. If the check ran in the same instant, it could see the **old** outputs from the previous instruction. The `#2` delay gives the logic time to settle before the outputs are read.

### What happens if `ins1` is never driven

An unassigned `logic` variable starts as `X`. If `ins1` is `X`, then `opcode` is `X`. No case item (`7'b0110011`, ...) matches an `X`, so no branch of the `case` runs. The outputs then keep the **defaults from the top of the block**, which are all `0`.

So with an undriven input, the control unit outputs **clean zeros, not `X`**. Evidence from a separate probe run (not part of the testbench):

```
ins1 never driven (X)   ins1=xxxxxxxx  alu_src=0 mem_read=0 mem_write=0 reg_write=0 branch=0 jump=0 jalr=0 mem_to_reg=00 alu_op=0000
```

This matters for testing: an expected value of all zeros (like the ILLEGAL test) would **pass even if the testbench forgot to drive `ins1`**. `===` does not help here, because the outputs are `0`, not `X`. This is why the testbench drives `ins1` explicitly before every check. The first `#2` at the start of the stimulus (line 55) also means `ins1` is `X` for the first 2 time units, before the ADD instruction is applied.

---

## 7. Test cases

Expected values are derived from the RISC-V instruction semantics (what each instruction needs the datapath to do) and this project's ALU encodings, not from reading the RTL's outputs. The expected-value column is in the vector order `{alu_src, mem_read, mem_write, reg_write, branch, jump, jalr, mem_to_reg, alu_op}`.

| # | Test | Input hex | Expected (13-bit) | Per signal | Why |
|---|---|---|---|---|---|
| 1 | ADD | `002081B3` | `0_0_0_1_0_0_0_00_0000` | alu_src=0, mem_read=0, mem_write=0, reg_write=1, branch=0, jump=0, jalr=0, mem_to_reg=00, alu_op=ADD | Register operands, writes the ALU result to `rd` |
| 2 | SUB | `402081B3` | `0_0_0_1_0_0_0_00_0001` | same as ADD, alu_op=SUB | Same as ADD, ALU subtracts |
| 3 | AND | `0020F1B3` | `0_0_0_1_0_0_0_00_0010` | same as ADD, alu_op=AND | Same as ADD, ALU ANDs |
| 4 | OR | `0020E1B3` | `0_0_0_1_0_0_0_00_0011` | same as ADD, alu_op=OR | Same as ADD, ALU ORs |
| 5 | XOR | `0020C1B3` | `0_0_0_1_0_0_0_00_0100` | same as ADD, alu_op=XOR | Same as ADD, ALU XORs |
| 6 | ADDI | `00500093` | `1_0_0_1_0_0_0_00_0000` | alu_src=1, reg_write=1, mem_to_reg=00, alu_op=ADD, rest 0 | Immediate operand, result written to `rd` |
| 7 | LW | `00002203` | `1_1_0_1_0_0_0_01_0000` | alu_src=1, mem_read=1, reg_write=1, mem_to_reg=01, alu_op=ADD, rest 0 | ALU makes the address, memory read, loaded data written to `rd` |
| 8 | SW | `00202023` | `1_0_1_0_0_0_0_00_0000` | alu_src=1, mem_write=1, alu_op=ADD, rest 0 | ALU makes the address, memory written, no register written |
| 9 | BEQ | `00410463` | `0_0_0_0_1_0_0_00_0001` | branch=1, alu_op=SUB, rest 0 | Subtract to compare; `zero` flag decides the branch; nothing written |
| 10 | JAL | `008003EF` | `0_0_0_1_0_1_0_10_0000` | reg_write=1, jump=1, mem_to_reg=10, rest 0 | Saves PC+4 in `rd`, jumps; ALU unused |
| 11 | JALR | `008304E7` | `1_0_0_1_0_0_1_10_0000` | alu_src=1, reg_write=1, jalr=1, mem_to_reg=10, alu_op=ADD, rest 0 | ALU makes the target `rs1+imm`; saves PC+4 in `rd` |
| 12 | ILLEGAL | `FFFFFFFF` | `0_0_0_0_0_0_0_00_0000` | all 0 | Unknown opcode: nothing happens (outputs fall to defaults) |

As a check on the testbench itself, I built an independent expected-value table from the rules above (in a scratch script, not from the RTL output) and compared it with the 12 literals in the testbench. All 12 matched.

---

## 8. Results

Command, run from a folder containing both files:

```
iverilog -g2012 -o control_tb_sim control_unit.sv control_unit_tb.sv && vvp control_tb_sim
```

Real console output (Icarus Verilog, run in WSL Ubuntu-22.04):

```
VCD info: dumpfile tb.vcd opened for output.
PASS ADD
PASS SUB
PASS AND
PASS OR
PASS XOR
PASS ADDI
PASS LW
PASS SW
PASS BEQ
PASS JAL
PASS JALR
PASS ILLEGAL
errors = 0
```

All 12 tests pass. The compile printed no warnings or errors, and the exit code was 0.

---

## Findings

None of these are failures of the 12 tests. They are observations, with evidence.

1. **R-type with an unsupported `funct7` or `funct3` is decoded as ADD and writes a register.** In the RTL, the inner `case` for R-type ends with `default: alu_op = 4'b0000;` and `reg_write` is already `1`. Probe run: `ins1 = 32'h022081B3` (R-type opcode with `funct7 = 0000001`, which is the MUL encoding, not supported here) gives `reg_write=1, alu_op=0000`. This is outside the supported instruction set, so it is not a bug for the 11 instructions, but unsupported R-type encodings are not rejected.
2. **The module decodes by opcode only for LW, SW, BEQ, JAL and JALR.** Other `funct3` values under the same opcode are not told apart. Again outside the supported set.
3. **The RTL contains extra decoding** (other R-type operations, and ANDI, ORI, XORI). That is out of scope for this document and untested here.
4. **The ILLEGAL test cannot detect a forgotten stimulus.** Because undriven `X` input falls to all-zero outputs (section 6), the ILLEGAL test would also pass without driving `ins1`. The testbench is correct because it does drive `ins1`, but a guard (for example, checking that `ins1` is not `X` before each check) would make that kind of mistake visible.
5. **The testbench writes `tb.vcd`.** `$dumpfile("tb.vcd")` and `$dumpvars` were already in the file. They were not added for this document, and `.vcd` files should not be committed.
6. **Outside this module:** `pc_top.sv` sets the JALR target to the raw ALU result (`rs1 + immediate`). The RISC-V spec says the lowest bit of a JALR target must be cleared. This does not affect the control unit.
