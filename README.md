# RISC-V Single-Cycle CPU

A processor I designed and verified from scratch in SystemVerilog. It runs real RISC-V machine code: a 32-bit, single-cycle CPU that implements 19 instructions of the RV32I instruction set.

I built it one small module at a time, tested each module on its own where it made sense, then connected everything and ran a 23-instruction program through the finished CPU. Every result is checked automatically by the testbenches (PASS/FAIL), not by eyeballing waveforms.

![The whole program running on the CPU](cpu_top/waveform.png)

*The full test program running in Vivado. The PC steps through the program and ends in the halt loop at 88. Registers x1 to x22 fill in as the instructions execute. x15, x18 and x21 stay at 0 because the instructions that would write them are deliberately jumped over.*

This README is written so that someone who has never studied computer architecture can follow it. If you already know how a CPU works, skip to [Design](#4-design) or [How I verified it](#7-how-i-verified-it).

## Contents

1. [What is a CPU, really?](#1-what-is-a-cpu-really)
2. [The theory you need](#2-the-theory-you-need)
3. [What this CPU supports](#3-what-this-cpu-supports)
4. [Design](#4-design)
5. [A walk through three instructions](#5-a-walk-through-three-instructions)
6. [Coding style](#6-coding-style)
7. [How I verified it](#7-how-i-verified-it)
8. [Bugs I found along the way](#8-bugs-i-found-along-the-way)
9. [Limitations and what is not tested](#9-limitations-and-what-is-not-tested)
10. [Repository layout and status](#10-repository-layout-and-status)
11. [Glossary](#11-glossary)

---

## 1. What is a CPU, really?

A CPU (central processing unit) is a machine that does one very simple thing, over and over:

1. Look at the next instruction in a list.
2. Do what it says. Usually that is "take these two numbers, do some maths, and store the answer".
3. Move on to the next instruction.

A program is just that list of instructions, stored as numbers. An instruction might say "add the numbers in boxes 1 and 2 and put the answer in box 3". Everything a computer does, from a game to a web browser, is billions of these tiny steps done very quickly.

This project is the machine that reads those instruction numbers and carries out the steps. It is written as a hardware description (RTL, register-transfer level): code that describes the circuits, which a simulator then runs, so I can watch exactly what each wire and register is doing.

## 2. The theory you need

### 2.1 Bits, bytes, words and hexadecimal

Computers store everything as bits, which are 0 or 1. This CPU works on **32-bit words**: groups of 32 bits, which can hold a number from 0 to about 4.29 billion. A **byte** is 8 bits, so a word is 4 bytes.

Writing 32 ones and zeros is painful, so we write them in **hexadecimal** (base 16), where each hex digit stands for 4 bits. For example, `0x00C00093` is the 32-bit instruction `0000 0000 1100 0000 0000 0000 1001 0011`.

### 2.2 Registers and memory

A CPU needs somewhere to keep numbers:

- **Registers** are a small set of very fast storage boxes inside the CPU. RISC-V has 32 of them, named `x0` to `x31`, each holding one 32-bit word. `x0` is special: it always reads as 0 and ignores writes. That turns out to be very handy (see the examples below).
- **Memory** is a much bigger array of storage outside the CPU's core. This design has two: an **instruction memory** (the program) and a **data memory** (the program's variables). Each has 256 words, which is 1 KB.

Memory is addressed **by byte**. Since each word is 4 bytes, consecutive words live at addresses 0, 4, 8, 12 and so on. This is why the CPU adds **4**, not 1, to move to the next instruction.

### 2.3 Instructions and the instruction set

An **instruction set architecture (ISA)** is the agreed list of instructions a CPU understands and how each one is encoded in bits. This project uses **RISC-V**, an open, modern ISA. "RV32I" means the 32-bit base integer instruction set. RISC stands for "reduced instruction set computer": a small set of simple instructions, which makes the hardware easy to build and to reason about.

Every RISC-V instruction is exactly 32 bits. The bits are split into fields:

| Field | What it holds |
|---|---|
| `opcode` | What kind of instruction this is (7 bits) |
| `rd` | The destination register to write the result into |
| `rs1`, `rs2` | The source registers to read |
| `funct3`, `funct7` | Extra bits that pick the exact operation (ADD vs SUB, and so on) |
| immediate | A constant number stored inside the instruction itself |

As an example, `add x3, x1, x2` ("x3 = x1 + x2") is encoded as:

```
funct7   rs2    rs1    funct3  rd     opcode
0000000  00010  00001  000     00011  0110011
```

which is `0x002081B3` in hex. The CPU's control unit looks at the `opcode` and `funct` bits to decide what to do.

### 2.4 Instruction formats

Different instructions need different fields, so RISC-V has a few layouts (formats). Bit 31 is on the left.

| Format | Bits 31..25 | 24..20 | 19..15 | 14..12 | 11..7 | 6..0 | Used by |
|---|---|---|---|---|---|---|---|
| R | funct7 | rs2 | rs1 | funct3 | rd | opcode | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I | imm[11:0] (bits 31..20) | | rs1 | funct3 | rd | opcode | ADDI, ANDI, ORI, XORI, LW, JALR |
| S | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode | SW |
| B | imm[12], imm[10:5] | rs2 | rs1 | funct3 | imm[4:1], imm[11] | opcode | BEQ |
| J | imm[20], imm[10:1], imm[11], imm[19:12] (bits 31..12) | | | | rd | opcode | JAL |

The immediate is cut into odd pieces in the S, B and J formats. That is a quirk of RISC-V: it keeps `rs1`, `rs2` and `rd` in the same bit positions for every format, so the register file can be read before the CPU even knows which instruction it is. The `imm_gen` module reassembles the pieces.

### 2.5 The instruction cycle

Every instruction goes through the same five stages:

1. **Fetch** - read the instruction from instruction memory at the address in the PC (program counter).
2. **Decode** - work out what it means (the control unit) and read the source registers.
3. **Execute** - the ALU (arithmetic logic unit) does the maths or computes an address.
4. **Memory** - if it is a load or store, access data memory.
5. **Write back** - store the result into the destination register.

The **PC** is a register that holds the address of the current instruction. Normally it goes up by 4 after each instruction. **Branches** and **jumps** change it to somewhere else, which is how loops and if-statements work.

### 2.6 The clock, combinational logic and sequential logic

Digital circuits come in two flavours:

- **Combinational logic** has no memory. Its output is purely a function of its inputs right now, like a calculator, and it reacts within a tiny delay. The ALU is combinational.
- **Sequential logic** remembers. It holds a value and only updates it at a particular moment, the rising edge of the **clock** (a signal that goes 0, 1, 0, 1 like a metronome). The PC, the register file and data memory writes are sequential.

Between two clock ticks, signals ripple through all the combinational logic and settle. On the next tick, the sequential parts capture their new values. That is the heartbeat of the whole design.

### 2.7 Negative numbers: two's complement and sign extension

Computers store negative numbers in **two's complement**. To get -16 in 32 bits: write 16 as `0x00000010`, flip every bit (`0xFFFFFFEF`), add 1 (`0xFFFFFFF0`). The top bit is the **sign bit**: 1 means negative.

An immediate inside an instruction is only 12 bits wide, but the ALU works on 32 bits. To widen a number without changing its value, copy the sign bit into all the new upper bits. This is called **sign extension**. For example, the 12-bit value `0xFF0` (which is -16) becomes `0xFFFFFFF0`, still -16. In SystemVerilog this is just bit replication:

```systemverilog
immediate = {{20{ins1[31]}}, ins1[31:20]};
```

The same 32 bits can be read as signed or unsigned, and the answer can differ. `0xFFFFFFF0` is -16 as a signed number but 4,294,967,280 as an unsigned one. That is exactly the difference between the **SLT** (signed less-than) and **SLTU** (unsigned less-than) instructions, and the test program checks both.

### 2.8 Why "single-cycle"?

In a **single-cycle** CPU, one whole instruction (fetch through write-back) happens in one clock cycle. It is the simplest possible CPU design, which makes it ideal for learning: every instruction takes the same time, and there is nothing to juggle. The cost is speed: the clock has to be slow enough for the slowest instruction (a load, which goes through almost every block). Real processors use **pipelining**, which overlaps the stages of several instructions at once. That is a natural next project (see [limitations](#9-limitations-and-what-is-not-tested)).

## 3. What this CPU supports

19 instructions of RV32I:

| Type | Instructions |
|---|---|
| Register-register (R) | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| Register-immediate (I) | ADDI, ANDI, ORI, XORI |
| Loads and stores | LW (load word), SW (store word) |
| Branch | BEQ (branch if equal) only |
| Jumps | JAL (jump and link), JALR (jump and link register) |

In plain words:

- **ADD / SUB** - add or subtract two registers.
- **AND / OR / XOR** - bitwise logic.
- **SLL / SRL / SRA** - shift left, shift right (logical), shift right (arithmetic: keeps the sign).
- **SLT / SLTU** - set the destination to 1 if one number is less than the other (signed / unsigned), else 0.
- **ADDI and friends** - same as above, but the second operand is a constant in the instruction.
- **LW / SW** - copy a word from memory into a register, or from a register into memory.
- **BEQ** - if two registers are equal, jump to PC + offset, otherwise continue.
- **JAL / JALR** - jump to another address and save the return address (PC + 4) in a register, which is how function calls work.

## 4. Design

### 4.1 Block diagram

```
              +-----------------------------------------------+
              |                                               |
              v                                               |
  pc_top --> pc --> instr_mem --> ins1 --+--> control_unit ---+--> control signals
   ^                                      |                    |
   |                                      +--> imm_gen --------+--> immediate
   |                                      |
   |                                      +--> register (rs1, rs2 read)
   |                                                |
   |                          alu_src               v
   |                       immediate --> alu_operand --> alu --> result, zero
   |                                                            |
   |   result (JALR target)                                     v
   +------------------------------------- data_mem (LW / SW) --> mem_data
   |   zero, branch, jump (BEQ / JAL)                           |
   |                                                            v
   +-------------------------------- wbmux (result / mem_data / PC+4) --> rd_data --> register write
```

Everything between clock edges is combinational. Only the PC, the register file and the SW write into data memory change on the clock edge.

### 4.2 The modules

| Module | Role |
|---|---|
| `pc_top` | Holds the PC and chooses the next one (PC+4, branch, JAL or JALR). Contains `programcounter`, `pc_adder`, `branch_addr` and `jump_addr` |
| `instr_mem` | 256-word instruction memory, read combinationally with `insmem[pc[9:2]]` |
| `imm_gen` | Extracts and sign-extends the immediate for I, S, B and J instructions |
| `control_unit` | Decodes the instruction into control signals and the ALU operation |
| `register` | 32 x 32-bit register file, two read ports, one write port |
| `alu_operand` | Chooses the ALU's second input: `rs2` or the immediate |
| `alu` | Arithmetic and logic, plus a `zero` flag |
| `data_mem` | 256-word data memory for LW and SW |
| `wbmux` | Chooses what is written back to the register: ALU result, memory data, or PC+4 |
| `cpu_top` | Wires all of the above together |

### 4.3 The interesting parts of each module

**`control_unit` - the brain.** It looks at the opcode (and funct bits for R-type) and sets a handful of one-bit switches. Everything else in the CPU just obeys them:

| Signal | Meaning |
|---|---|
| `alu_src` | 0 = ALU's second input is `rs2`, 1 = it is the immediate |
| `reg_write` | write a result into the register file |
| `mem_read` / `mem_write` | read or write data memory |
| `mem_to_reg` | what to write back: 00 = ALU result, 01 = memory data, 10 = PC+4 |
| `branch` / `jump` / `jalr` | which kind of control transfer |
| `alu_op` | 4-bit code for the ALU operation |

The values for each instruction type:

| Instruction | alu_src | mem_read | mem_write | reg_write | mem_to_reg | branch | jump | jalr | alu_op |
|---|---|---|---|---|---|---|---|---|---|
| R-type | 0 | 0 | 0 | 1 | 00 | 0 | 0 | 0 | from funct3/funct7 |
| ADDI/ANDI/ORI/XORI | 1 | 0 | 0 | 1 | 00 | 0 | 0 | 0 | ADD/AND/OR/XOR |
| LW | 1 | 1 | 0 | 1 | 01 | 0 | 0 | 0 | ADD (address) |
| SW | 1 | 0 | 1 | 0 | n/a | 0 | 0 | 0 | ADD (address) |
| BEQ | 0 | 0 | 0 | 0 | n/a | 1 | 0 | 0 | SUB (zero flag) |
| JAL | n/a | 0 | 0 | 1 | 10 | 0 | 1 | 0 | n/a |
| JALR | 1 | 0 | 0 | 1 | 10 | 0 | 0 | 1 | ADD (rs1 + imm) |

The ALU operation codes:

| `alu_op` | Operation | `alu_op` | Operation |
|---|---|---|---|
| 0000 | ADD | 0101 | SLL |
| 0001 | SUB | 0110 | SRL |
| 0010 | AND | 0111 | SRA |
| 0011 | OR | 1000 | SLT |
| 0100 | XOR | 1001 | SLTU |

**`alu` - arithmetic and the zero flag.** A single `case` on `alu_op`. The shifts use only the low 5 bits of the second operand (you cannot shift a 32-bit number by more than 31). SRA needs `$signed(...) >>> ...` so the sign bit is copied in. The signed and unsigned comparisons differ only in whether the operands are cast with `$signed`. A `zero` output is high when the result is 0. The branch logic uses it.

**`imm_gen` - putting the immediate back together.** It picks the right bit slices for the format and sign-extends. Branch and jump offsets are always even, so bit 0 is a hard-wired `0`:

```systemverilog
// B-type: the immediate is scattered across the instruction
immediate = {{19{ins1[31]}}, ins1[31], ins1[7], ins1[30:25], ins1[11:8], 1'b0};
```

**`register` - the register file.** Two combinational read ports and one write on the clock edge. Reading `x0` returns 0 and writing `x0` is ignored, so `x0` is a hard-wired zero. That gives you tricks for free: `addi x1, x0, 12` means "put the constant 12 in x1".

**`data_mem` - memory.** Reads are combinational (gated by `mem_read`); writes happen on the clock edge (gated by `mem_write`). The address is `result[9:2]`, the ALU result with the lowest two bits dropped (each word is 4 bytes). Only 10 address bits are used, so the 1 KB memory wraps around.

**`pc_top` - choosing the next instruction.** The PC register holds the address; combinational logic picks the next value in this priority order:

```systemverilog
if (branch_taken)  pc_next = branch_target;           // BEQ and the registers are equal
else if (jump)     pc_next = jump_target;             // JAL
else if (jalr)     pc_next = {result[31:1], 1'b0};    // JALR, bit 0 cleared as the spec requires
else               pc_next = pcplus4;                 // normal flow
```

`branch_taken` is simply `branch & zero`. BEQ makes the ALU subtract the two registers, and if the result is zero they were equal. `branch_addr` and `jump_addr` are the same adder (PC + immediate); I kept them as two modules so each target has a clear name in `pc_top`.

**`wbmux` - picking what to write back.** A three-way choice: the ALU result (most instructions), the memory data (LW), or PC+4 (the return address saved by JAL and JALR).

**`alu_operand` - choosing the second ALU input.** One signal, `alu_src`, picks `rs2` (for R-type) or the immediate (for I-type, loads and stores).

## 5. A walk through three instructions

### `add x3, x1, x2`

1. **Fetch**: `instr_mem` returns the word at the PC.
2. **Decode**: `control_unit` sees opcode `0110011` (R-type) and sets `reg_write=1`, `alu_src=0`, and picks ADD from funct3/funct7. The register file reads x1 and x2.
3. **Execute**: `alu_operand` passes `rs2` through. The ALU adds x1 + x2.
4. **Memory**: nothing, `mem_read` and `mem_write` are 0.
5. **Write back**: `wbmux` selects the ALU result. On the clock edge it is stored in x3, and the PC goes to PC + 4.

### `lw x14, 16(x0)`

1. **Fetch and decode**: opcode `0000011` makes `control_unit` set `alu_src=1`, `mem_read=1`, `reg_write=1`, `mem_to_reg=01`. `imm_gen` produces 16. The register file reads x0, which is 0.
2. **Execute**: the ALU adds 0 + 16 = 16. That is the memory address.
3. **Memory**: `data_mem` reads word `16 >> 2 = 4` (that is `result[9:2]`).
4. **Write back**: `wbmux` selects the memory data and the clock edge stores it in x14.

### `beq x3, x14, +8`

1. **Decode**: opcode `1100011` sets `branch=1` and tells the ALU to subtract. `imm_gen` rebuilds the offset, 8.
2. **Execute**: the ALU computes x3 - x14. If they are equal the result is 0, so `zero=1`.
3. **Next PC**: `pc_top` sees `branch & zero` and sets `pc_next = PC + 8`. The instruction in between is skipped. If the registers were different, `zero=0` and the PC simply goes to PC + 4.
4. No register or memory is written.

## 6. Coding style

I kept the style simple and consistent so the design is easy to read and check:

- **One job per module.** Each small module does exactly one thing, and `cpu_top` is almost entirely wiring. That is what made module-by-module testing possible.
- **`logic` for every signal**, with no mixing of `reg` and `wire`.
- **Combinational logic in `always_comb`, with default values assigned at the top of the block.** Every output gets a value on every path, so no accidental latches can be inferred. `control_unit`, `alu_operand`, `wbmux` and `data_mem` all do this.
- **Sequential logic in `always_ff @(posedge clk)` with non-blocking `<=`**, used only for the PC, the register file and data memory writes.
- **One-line `assign` statements for tiny pieces of logic** such as `pc_adder`, `branch_addr`, `jump_addr` and the `zero` flag.
- **Named port connections** everywhere in `cpu_top` (`.clk(clk)`), so wiring mistakes are visible.
- **`case` statements for decoding**, with a comment for each mnemonic.
- **Sign extension by replication** (`{{20{sign}}, ...}`) rather than any clever arithmetic.
- **Plain signals instead of enums or packages.** The control signals are one-bit flags and small vectors. That is deliberately simple, so a beginner can follow every signal in a waveform.
- **Instances in `cpu_top` are named `dut1` to `dut9`.** The testbench relies on these names to reach inside the CPU (for example `dut.dut5.regfile` is the register file).

## 7. How I verified it

### The approach

I tested from the bottom up. Every small module that has meaningful behaviour on its own has its own testbench, and only then did I connect the modules and run the whole CPU. If the full CPU had failed, I would already have known that the individual pieces were right.

### Self-checking testbenches

Each testbench compares the actual output with the expected value, prints `PASS` or `FAIL` for every check, counts the failures and prints a final summary. There is nothing to interpret by eye.

Style rules I followed in every testbench:

- **Inputs change away from the clock edge** (at the falling edge).
- **Outputs are checked shortly after the rising edge** (2 time units after it), after the logic has settled. Checking in the same instant that an input changes gives wrong answers, because the simulator may not have updated the outputs yet. This is a simulation race, and I hit it for real (see below).
- **The testbenches use plain tasks and an `errors` counter** and end with a single `ALL PASSED` or a failure count.

### Unit tests and the full-CPU test

The unit testbenches check each module in isolation (ALU operations, immediate generation for each format, register file reads and writes including `x0`, control signals for each opcode, data memory reads and writes, and PC selection for branch, jump and JALR). The `pc_top` and `cpu_top` tests were run in Vivado.

### The full-CPU test (`cpu_top`)

The most important test loads a 23-instruction program into instruction memory, releases reset and then, after every instruction, checks two things:

- **the PC** points to the correct next instruction;
- **the destination register** holds the correct value.

The one instruction that writes data memory (SW) is also checked directly in memory with an assert.

The program covers every instruction kind once: arithmetic and logic, a negative immediate, signed vs unsigned compare, a store followed by a load of the same address, a taken branch, a not-taken branch, JAL and JALR. It ends in a halt loop (`beq x0, x0, 0` branches to itself) so the PC parks at 88. Instructions that should be skipped (after a taken branch or a jump) write a "poison" value of 99, and the test checks that the register stays 0, which proves the skip worked. In total: 21 register checks, 22 PC checks and 1 memory assert.

See [`cpu_top/`](cpu_top/) for the full program, expected values and screenshots.

## 8. Bugs I found along the way

Testing was not just a formality. It found real problems:

1. **JALR did not clear bit 0 of its target.** The RISC-V spec requires the jump target to be `(rs1 + imm)` with the lowest bit forced to 0. My first version used the ALU result as it was. The `pc_top` test with an odd target exposed it, and the fix is one line (`{result[31:1], 1'b0}`).
2. **A signal used before it was declared.** In `cpu_top`, the ALU's `result` was connected to `pc_top` above the line that declared it. Some simulators quietly create a 1-bit wire for it, which would be a very confusing bug. Moving the declaration to the top fixed it. I found it while reviewing with all compiler warnings turned on.
3. **A false failure from a simulation race.** My first ALU testbench failed on the SLTU check even though the ALU was right. I was changing the inputs and reading the output in the same instant. Adding a delay before the check fixed it, and it is why the rule "check after the clock edge, not at the same moment as the stimulus" is now part of every testbench.

## 9. Limitations and what is not tested

I would rather be upfront about what this project does and does not do.

**Not implemented:**

- Only **BEQ** is implemented. BNE, BLT, BGE, BLTU and BGEU are not supported.
- **Immediate shifts** (SLLI, SRLI, SRAI) and **SLTI / SLTIU** are not decoded by the control unit. An unsupported I-type instruction falls back to ADD, so it would silently behave like ADDI.
- **LUI and AUIPC** are not implemented (so you cannot build a 32-bit constant in two instructions).
- **Byte and halfword memory access** (LB, LH, SB, SH) are not implemented. Only whole words.
- No exceptions, interrupts or system instructions (ECALL, EBREAK, FENCE).
- JALR clears bit 0 as the spec requires, but bit 1 is not checked, so a JALR target that is not a multiple of 4 is not trapped.
- Memory is only 256 words each, and addresses wrap around. There is no program loader: the testbench writes instruction words straight into `instr_mem`.

**Not fully tested:**

- The full-CPU test is **one fixed program**. It runs each instruction type once with one set of values. It is not a random test and it does not use the official RISC-V compliance suite.
- SLL, SRL and SRA are implemented in the ALU but the full-CPU program does not run them.
- `instr_mem`, `alu_operand` and `wbmux` have no standalone testbenches. They are only covered by the full-CPU test.
- The design is **only simulated** (Vivado xsim and Icarus). It has not been synthesised or run on an FPGA.

**Ideas for next steps:** the remaining branches, immediate shifts and SLTI, LUI/AUIPC, byte and halfword loads and stores, loading programs with `$readmemh`, running the official RISC-V compliance tests, a 5-stage pipeline version, and synthesis on an FPGA.

## 10. Repository layout and status

```
RISC-V-single-cycle/
|-- alu/             ALU, testbench, result, README
|-- imm_gen/         immediate generator, testbench, result, README
|-- register/        register file, testbench, result, README
|-- control_unit/    control unit, testbench, results (log and waveform), README
|-- data_mem/        data memory, testbench, results (log and waveform), README
|-- pc_top/          PC logic (programcounter, pc_adder, branch_addr, jump_addr), testbench, results, README
|-- cpu_top/         top level, full-CPU testbench, results, README
|   `-- rtl/         modules without their own testbench: instr_mem, alu_operand, wbmux
|-- .gitignore       keeps simulator output (waveform dumps, build files) out of the repo
`-- README.md        this file
```

| Module | Folder | How it was verified |
|---|---|---|
| ALU | [`alu/`](alu/) | own testbench |
| Immediate generator | [`imm_gen/`](imm_gen/) | own testbench |
| Register file | [`register/`](register/) | own testbench |
| Control unit | [`control_unit/`](control_unit/) | own testbench |
| Data memory | [`data_mem/`](data_mem/) | own testbench |
| PC logic | [`pc_top/`](pc_top/) | own testbench, run in Vivado |
| Instruction memory, ALU operand mux, write-back mux | [`cpu_top/rtl/`](cpu_top/rtl/) | covered by the full-CPU test only |
| Top level (`cpu_top`) | [`cpu_top/`](cpu_top/) | full-program testbench, run in Vivado |

Each folder has its own README that says exactly what was tested and what was not. Unit testbenches were run with Icarus Verilog and viewed in GTKWave. The `pc_top` and `cpu_top` tests were run in Vivado.

## 11. Glossary

| Term | Meaning |
|---|---|
| **ALU** | Arithmetic logic unit: the circuit that adds, subtracts and does logic |
| **Bit / byte / word** | 1 binary digit / 8 bits / 32 bits in this design |
| **Branch** | An instruction that may change the PC depending on a condition |
| **Clock** | A signal that ticks 0-1-0-1; sequential parts update on the rising edge |
| **Combinational logic** | Logic with no memory; the output depends only on the current inputs |
| **Control signals** | The switches (`reg_write`, `alu_src`, ...) that steer the datapath |
| **Datapath** | The wires and blocks the data travels through |
| **Immediate** | A constant stored inside the instruction |
| **ISA** | Instruction set architecture: the list of instructions and their encoding |
| **Opcode** | The field that says what kind of instruction it is |
| **PC** | Program counter: the address of the current instruction |
| **Pipeline** | Overlapping several instructions at different stages to go faster |
| **Register** | A small, fast storage box inside the CPU |
| **RTL** | Register-transfer level: describing hardware as registers and the logic between them |
| **Sequential logic** | Logic that stores state and updates on the clock edge |
| **Sign extension** | Widening a signed number by copying its sign bit |
| **Single-cycle** | Each instruction completes in exactly one clock cycle |
| **Two's complement** | The way computers store negative integers |
