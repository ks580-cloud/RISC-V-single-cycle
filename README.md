# RISC-V Single-Cycle CPU

A single-cycle RISC-V (RV32I subset) processor written in SystemVerilog. The design is built and verified module by module: modules are added one at a time, and each comes with its own testbench.

## Status

- [x] ALU (see [`alu/`](alu))
- [x] Immediate generator (see /imm_gen)
- [ ] Control unit
- [ ] Register file
- [ ] Data memory
- [ ] PC logic
- [ ] Top-level integration (to be simulated in Vivado)
