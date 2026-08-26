# 8-Bit Computer

A complete 8-bit computer, designed and implemented from first principles. The project spans the entire stack: a custom instruction set architecture, an assembly language, a two-pass assembler with label resolution, and an instruction-level simulator written in C. I built every layer from scratch, without tutorials or reference implementations, making the architectural and encoding decisions myself at each step. Together these pieces demonstrate computer architecture, instruction-set design, and low-level systems programming as one cohesive, working system.

Verilog FPGA implementation is underway on a Digilent Basys 3. New Verilog files and demos (including video of the board running) will be added once their implementation is complete.

Update as of August 26, 2026: RTL implementation complete and verified against the C simulator across the full instruction set; 
FPGA bring-up in progress.

---

## Architecture and Conventions

**8-bit icode**

| icode | Register A | Register B |
|-------|------------|------------|
| 4 bits | 2 bits | 2 bits |

- `%rA` and `%rB` refer to the values stored in the selected registers, unless explicitly discussing the instruction bit fields
- icodes `0x0`, `0xC`, `0xD`, `0xE`, `0xF` have subinstructions depending on the value B (2 bits of rB)

### Registers

| Register | Type / Description / Calling Conventions |
|----------|------------------------------------------|
| r0 | Stores return value from functions; caller-save; 1st argument |
| r1 | Caller-save; 2nd argument |
| r2 | Caller-save; 3rd argument |
| r3 | Callee-save |
| pc | Program counter, initially set to `0x00`. Memory address of the current instruction; increments by 1 following every instruction unless otherwise specified |
| rsp | Register stack pointer, initially set to `0xFF`. Memory address of the top of the stack |

- Additional arguments beyond `%r0`, `%r1`, `%r2` are passed on the stack. Exact ordering should be specified before writing multi-argument function calls.
- All general-purpose registers are 8-bit. Arithmetic results wrap modulo 256 unless otherwise specified.
- Functions may freely overwrite `%r0`, `%r1`, `%r2` but must restore `%r3` before returning if they modify it.
- All registers are zeroed before the simulator runs.

### Stack Conventions

- The stack follows a last-in, first-out structure and grows downwards from `0xFF`.
- rsp is initialized to `0xFF`.
- Only values stored in registers can be pushed to or popped from the stack directly.
- **PUSH** to the top of the stack decrements rsp and sets `M[rsp]` = value stored in register A.
- **POP** from the top of the stack increments rsp, and the value of register A = `M[rsp]`.
- **CALL** pushes the return address `pc + 2` onto the stack, then jumps to the address stored in `M[pc + 1]`.
- **RETURN** pops the return address from the stack into the pc.

### Assembly Format

`mov %r0, %r1` moves the value stored in r0 to r1 (r0 does not change), following an `Instruction Source, Destination` format.

| Operand | Identifier | Description |
|---------|------------|-------------|
| Register | `%r0`, `%r1`, `%r2`, `%r3` | A percent sign designates values stored in registers |
| PC | `pc` | `pc` gathers the current instruction's address |
| Immediate Value | `$10`, `$20`, etc. | A dollar sign indicates an immediate value |
| Memory Address | `($10)` or `(%r0)` | Parentheses signify a memory address |
| RSP | `rsp` | `rsp` points to the top of the stack |

### Labels

Labels take the place of memory addresses and are treated as immediate values; they can simplify function calls, gotos, or loops. Duplicate labels will cause errors. See the table below for label usage.

| Label Function | Label Usage |
|----------------|-------------|
| Declaring a label | On a new line, write the label name followed by a colon: `label:` or `myfunction:` or `foo:` |
| Using a label | Simply replace an operand with a label name (no colon): `mov label, %r0` or `call myfunction` or `je %r1, foo` |

Additionally, for the assembly instructions that use labels, replacing the labels with hardcoded immediate values will not impact functionality.

### Comments

- To declare a comment, use a double forward slash `//`
- In-line comments are not supported
- Comments (as well as empty lines) are counted in line numbers

### Error Catching

Syntax errors (incorrect formatting, operands, instructions, etc.) are displayed in stderr with the corresponding line number. Comments and blank lines are included in line number counts for error reporting.

---

## Worked Example: Exponent Function

Below is an example exponential program to demonstrate various features of my architecture. It computes base^exponent with base in `%r0` and exponent in `%r1`. My function supports the exponent = 0 edge case.

| Line | Code |
|------|------|
| 1 | `// load base into %r0 and exponent into %r1` |
| 2 | `mov $05, %r0` |
| 3 | `mov $03, %r1` |
| 4 | `mov $38, %r3` |
| 5 | |
| 6 | `// call exponent function then halt` |
| 7 | `call exponent` |
| 8 | `halt` |
| 9 | |
| 10 | `// exponent function label` |
| 11 | `exponent:` |
| 12 | |
| 13 | `// check for exponent = 0` |
| 14 | `je %r1, zero` |
| 15 | |
| 16 | `// pre-loop housekeeping` |
| 17 | `push %r3` |
| 18 | `mov %r0, %r3` |
| 19 | `add $FF, %r1` |
| 20 | |
| 21 | `// multiplication loop` |
| 22 | `loop:` |
| 23 | `jgt %r1, body` |
| 24 | `pop %r3` |
| 25 | `ret` |
| 26 | |
| 27 | `// body of loop` |
| 28 | `body:` |
| 29 | `mul %r3, %r0` |
| 30 | `add $FF, %r1` |
| 31 | `jmp loop` |
| 32 | |
| 33 | `// exponent = 0` |
| 34 | `zero:` |
| 35 | `mov $01, %r0` |
| 36 | `ret` |

### Register Demonstrations

*Register values shown in decimal; rsp and addresses shown in hex.*

| Instruction phase / label | Register Contents | Description |
|---------------------------|-------------------|-------------|
| Loading phase (lines 2–4) | %r0 = 5, %r1 = 3, %r3 = 56, rsp = 0xFF | I load the base into %r0, the exponent into %r1, and store a placeholder value in %r3 (for demonstration purposes) |
| Function Call (line 7) | %r0 = 5, %r1 = 3, %r3 = 56, rsp = 0xFF | Program jumps to the exponent label on line 11 |
| Exponent = 0 Case (line 14) | %r0 = 5, %r1 = 3, %r3 = 56, rsp = 0xFF | Before the multiplication loop, I check whether the exponent is zero (%r1). If so, I jump to line 34. |
| Pre-loop housekeeping (lines 17–19) | %r0 = 5, %r1 = 2, %r3 = 5, rsp = 0xFE | Since %r3 is callee-save, I push it to the stack before modification. %r3 now holds a copy of base (%r0) |
| Pre-loop check (line 23) | %r0 = 5, %r1 = 2, %r3 = 5, rsp = 0xFE | This check makes my loop a while loop instead of a do-while loop. I check the condition before entering the loop, fixing the case where zero multiplications are needed. |
| Loop Body – 1st iteration (lines 29–31) | %r0 = 25, %r1 = 1, %r3 = 5, rsp = 0xFE | I complete my first multiplication cycle and update the counter register. Since my ISA has no native looping construct, I use an unconditional jump back to line 23 |
| Pre-loop check (line 23) | %r0 = 25, %r1 = 1, %r3 = 5, rsp = 0xFE | Again, I check whether the exponent is greater than zero. In this case, %r1 = 1, so I jump to the loop body a second time |
| Loop Body – 2nd iteration (lines 29–31) | %r0 = 125, %r1 = 0, %r3 = 5, rsp = 0xFE | I complete my second multiplication cycle and update the counter register. %r0 now holds the correct output 125 while the counter %r1 is zero. After the loop, I jump back to line 23 |
| Pre-loop check, pop, and return (lines 23–25) | %r0 = 125, %r1 = 0, %r3 = 56, rsp = 0xFF | Since %r1 = 0, which is not greater than zero, line 23 does not jump to the body label and instead goes to line 24. Line 24 pops from the stack, restoring %r3 to the pre-call value. Line 25 returns from the function call. Notice that %r0 holds the return value for function calls. |
| Halt (line 8) | %r0 = 125, %r1 = 0, %r3 = 56, rsp = 0xFF | Halt stops the program and prompts the simulator to display register values. |

```
Program Completed

Register Values:
r0: 125  0x7D
r1:   0  0x00
r2:   0  0x00
r3:  56  0x38

pc:    8  0x08
rsp: 255  0xFF
halt: true
```

### Edge Case: %r1 = 0

*This example acts as though the exponent is zero; it deviates from the previous example on line 14.*

| Instruction phase / label | Register Contents | Description |
|---------------------------|-------------------|-------------|
| Exponent = 0 Case (line 14) | %r0 = 5, %r1 = 0, %r3 = 56, rsp = 0xFF | Before the multiplication loop, I check whether the exponent is zero (%r1). Since it is, I jump to line 34 |
| Zero label (lines 34–36) | %r0 = 1, %r1 = 0, %r3 = 56, rsp = 0xFF | Since this check is before pushing %r3, I do not need to pop %r3. I move 1 into %r0, setting the return value to one, then return. |
| Halt (line 8) | %r0 = 1, %r1 = 0, %r3 = 56, rsp = 0xFF | Halt stops the program and prompts the simulator to display register values. |

---

## Icode and Assembly Tables

### Icode Table

| icode | Operation | Description |
|-------|-----------|-------------|
| `0x0` (`0000`) | B-dependent: `0` rA = -rA; `1` rA = ~rA; `2` rA = !rA; `3` rA = pc | `0` Negate rA; `1` Bitwise negate rA; `2` Not rA; `3` Load pc into rA |
| `0x1` (`0001`) | rA = rB | Set rA equal to rB |
| `0x2` (`0010`) | rA += rB | Add registers rA and rB; store in rA |
| `0x3` (`0011`) | rA -= rB | Subtract registers rA and rB; store in rA |
| `0x4` (`0100`) | rA *= rB | Multiply register rA by rB; store in rA. For overflow, lower 8 bits stored in rA |
| `0x5` (`0101`) | rA <<= rB | Left shift rA by rB; store in rA. Only lower 3 bits of rB are used |
| `0x6` (`0110`) | rA >>= rB | Right shift rA by rB; store in rA. Only lower 3 bits of rB are used |
| `0x7` (`0111`) | rA &= rB | Bitwise AND rA and rB; store in rA |
| `0x8` (`1000`) | rA \|= rB | Bitwise OR rA and rB; store in rA |
| `0x9` (`1001`) | rA ^= rB | Bitwise XOR rA and rB; store in rA |
| `0xA` (`1010`) | rA = M[rB] | Set rA equal to memory at the address stored in rB |
| `0xB` (`1011`) | M[rB] = rA | Set memory at the address stored in rB to rA |
| `0xC` (`1100`) | B-dependent (then pc + 2): `0` rA = M[pc+1]; `1` rA += M[pc+1]; `2` M[rA] = M[pc+1]; `3` rA = M[M[pc+1]] | `0` Load the immediate byte into rA; `1` Add value in memory at pc+1 to rA; `2` Load the immediate byte into the address stored in rA; `3` Use the byte after the instruction as a memory address, load the value stored there into rA |
| `0xD` (`1101`) | B-dependent (rA treated as signed): `0` if rA > 0: pc = M[pc+1] else pc+2; `1` if rA < 0: pc = M[pc+1] else pc+2; `2` if rA = 0: pc = M[pc+1] else pc+2; `3` if rA != 0: pc = M[pc+1] else pc+2 | `0` if rA > 0, jump to address at pc+1, else increment pc by 2; `1` if rA < 0, jump to address at pc+1, else increment pc by 2; `2` if rA = 0, jump to address at pc+1, else increment pc by 2; `3` if rA != 0, jump to address at pc+1, else increment pc by 2 |
| `0xE` (`1110`) | B-dependent: `0` rsp -= 1, M[rsp] = rA; `1` rsp -= 1, M[rsp] = M[pc+1], pc+2; `2` rA = M[rsp], rsp += 1; `3` rA = rsp | `0` Push value in rA to the top of the stack; `1` Push value in the immediate byte to the top of the stack; `2` Pop the top stack value into rA; `3` Load rsp into rA |
| `0xF` (`1111`) | B-dependent: `0` pc = M[pc+1]; `1` rsp -= 1, M[rsp] = pc+2, pc = M[pc+1]; `2` pc = M[rsp], rsp += 1; `3` Halt | `0` Unconditional jump to address stored in the immediate byte; `1` Call a function; `2` Return from a function; `3` Ends program, sets the `halt` flag to true |

### Assembly Language

| Assembly | Syntax | Operation | icode | Valid Registers |
|----------|--------|-----------|-------|-----------------|
| neg | `neg %rA` | rA = -rA | `0x0` | rA |
| bnot | `bnot %rA` | rA = ~rA | `0x0` | rA |
| lnot | `lnot %rA` | rA = !rA | `0x0` | rA |
| mov | `mov pc, %rA` | rA = pc | `0x0` | rA |
| mov | `mov %rB, %rA` | rA = rB | `0x1` | rA, rB |
| add | `add %rB, %rA` | rA += rB | `0x2` | rA, rB |
| sub | `sub %rB, %rA` | rA -= rB | `0x3` | rA, rB |
| mul | `mul %rB, %rA` | rA *= rB | `0x4` | rA, rB |
| shl | `shl %rB, %rA` | rA <<= rB | `0x5` | rA, rB |
| shr | `shr %rB, %rA` | rA >>= rB | `0x6` | rA, rB |
| and | `and %rB, %rA` | rA &= rB | `0x7` | rA, rB |
| or | `or %rB, %rA` | rA \|= rB | `0x8` | rA, rB |
| xor | `xor %rB, %rA` | rA ^= rB | `0x9` | rA, rB |
| mov | `mov (%rB), %rA` | rA = M[rB] | `0xA` | rA, rB |
| mov | `mov %rA, (%rB)` | M[rB] = rA | `0xB` | rA, rB |
| mov | `mov $imm, %rA` | rA = M[pc + 1] | `0xC` | rA |
| add | `add $imm, %rA` | rA += M[pc + 1] | `0xC` | rA |
| mov | `mov $imm, (%rA)` | M[rA] = M[pc + 1] | `0xC` | rA |
| mov | `mov ($imm), %rA` | rA = M[M[pc + 1]] | `0xC` | rA |
| jgt | `jgt %rA, label` | if rA > 0: pc = M[pc + 1] else pc + 2 | `0xD` | rA |
| jlt | `jlt %rA, label` | if rA < 0: pc = M[pc + 1] else pc + 2 | `0xD` | rA |
| je | `je %rA, label` | if rA = 0: pc = M[pc + 1] else pc + 2 | `0xD` | rA |
| jne | `jne %rA, label` | if rA != 0: pc = M[pc + 1] else pc + 2 | `0xD` | rA |
| push | `push %rA` | rsp -= 1; M[rsp] = rA | `0xE` | rA |
| push | `push $imm` | rsp -= 1; M[rsp] = M[pc + 1]; pc + 2 | `0xE` | none |
| pop | `pop %rA` | rA = M[rsp]; rsp += 1 | `0xE` | rA |
| mov | `mov rsp, %rA` | rA = rsp; pc + 1 | `0xE` | rA |
| jmp | `jmp label` | pc = M[pc + 1] | `0xF` | none |
| call | `call label` | rsp -= 1; M[rsp] = pc + 2; pc = M[pc + 1] | `0xF` | none |
| ret | `ret` | pc = M[rsp]; rsp += 1 | `0xF` | none |
| halt | `halt` | Halt | `0xF` | none |

---

## Build Instructions

There are a few ways to build and run the program. Here is the easiest:

1. Place an assembler program in a `.txt` file (in the same folder as the `.c` files).
2. Use the command `make all` to compile the assembler and simulator.
3. Use the command `./assembler program.txt | ./simulator` to run the assembler and pipe its output to the simulator.
   - `program.txt` just needs to be a `.txt` file; it can be named anything.
4. Output is printed to stdout.

**Other useful commands**

- `make clean` removes all builds
- `make assembler` or `make simulator` builds the assembler or simulator respectively
- To run the assembler by itself, use `./assembler program.txt`
- `ctrl c` ends the program if it enters an infinite loop

---

## Example Programs

Other than the exponent program used for the worked example, this repo has three other example programs. The notes below explain how to use each program.

### Division

This is a basic integer division program. The dividend is loaded into `%r0` (line 2) and the divisor is loaded into `%r1` (line 3). `%r0` displays the output after the function returns. Dividing by zero halts the program.

### Binary Search

The binary search program initializes a sorted array of 8 values in memory. The array starts at address `0xC0` to sit clear of the program below it, and each value is stored contiguously in memory. Binary search places a target value into `%r0` (line 22), the low bound of the array into `%r1` (line 23), and the high bound of the array into `%r2` (line 24). The program then searches through the array and returns the index of the target value in `%r0`. If the target is not found within the array, the function returns `0xFF`.

### Population Count

The population count program tallies the number of set bits (bits that are 1) within a byte. The input byte is stored in `%r0` (line 2), then the function returns the number of set bits.
