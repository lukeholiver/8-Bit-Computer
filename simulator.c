#include "simulator.h"  

// initlaize cpu fields
void init_cpu(CPU *cpu){
    memset(cpu, 0, sizeof(*cpu));
    cpu->rsp = 0xFF;
    cpu->halt = false;
}

// check for valid program
bool safety_check(char *program){
    
    int count = 0;

    if(program == NULL){
        return false;
    }

    for(int i = 0; program[i] != '\0'; i++){
        if(!isxdigit((unsigned char)program[i])){
            return false;
        }
        count ++;
    }

    if(count == 0){
        return false;
    }

    if(count % 2 != 0){
        return false;
    }

    if((count / 2) > 256){
        return false;
    }

    return true;
}

// load code to memory
void load_memory(CPU *cpu, char *program){
    uint8_t mem_addr = 0;

    for(int i = 0; program[i] != '\0'; i += 2){

        char byte_str[3];

        byte_str[0] = program[i];
        byte_str[1] = program[i + 1];
        byte_str[2] = '\0';

        unsigned long hex_byte = strtoul(byte_str, NULL, 16);
        cpu->memory[mem_addr] = (uint8_t)hex_byte;
        mem_addr ++;
    }
}

// fetch one instruction
uint8_t fetch_instruction(const CPU *cpu){
    return cpu->memory[cpu->pc];
}

// execute one instruction
void execute_instruction(CPU *cpu, uint8_t instruction){
    
    // Parse/decode instruction into icode, rA, and rB

    int icode = instruction >> 4;
    int rA = (instruction >> 2) & 0x03;
    int rB = instruction & 0x03;

    // Execute instruction

    uint8_t new_pc = cpu->pc + 1;

    switch(icode){

        case 0x0:
            switch(rB){
    
                case 0x0:
                    cpu->rfile[rA] = -cpu->rfile[rA]; 
                    break;

                case 0x1:
                    cpu->rfile[rA] = ~cpu->rfile[rA]; 
                    break;

                case 0x2:
                    cpu->rfile[rA] = !cpu->rfile[rA]; 
                    break;

                case 0x3:
                    cpu->rfile[rA] = cpu->pc;
                    break;
            }
            break;

        case 0x1:
            cpu->rfile[rA] = cpu->rfile[rB]; 
            break;

        case 0x2:
            cpu->rfile[rA] += cpu->rfile[rB];
            break;

        case 0x3:
            cpu->rfile[rA] -= cpu->rfile[rB];
            break;

        case 0x4:
            cpu->rfile[rA] *= cpu->rfile[rB];
            break;

        case 0x5:
            cpu->rfile[rA] <<= (cpu->rfile[rB] & 0x07);
            break;

        case 0x6:
            cpu->rfile[rA] >>= (cpu->rfile[rB] & 0x07);
            break;

        case 0x7:
            cpu->rfile[rA] &= cpu->rfile[rB];
            break;

        case 0x8:
            cpu->rfile[rA] |= cpu->rfile[rB];
            break;

        case 0x9:
            cpu->rfile[rA] ^= cpu->rfile[rB];
            break;

        case 0xA:
            cpu->rfile[rA] = cpu->memory[cpu->rfile[rB]];
            break;

        case 0xB:
            cpu->memory[cpu->rfile[rB]] = cpu->rfile[rA];
            break;

        case 0xC:

           switch(rB){

                case 0x0:
                    cpu->rfile[rA] = cpu->memory[cpu->pc + 1];
                    break;

                case 0x1:
                    cpu->rfile[rA] += cpu->memory[cpu->pc + 1];
                    break;

                case 0x2:
                    cpu->rfile[rA] &= cpu->memory[cpu->pc + 1];
                    break;

                case 0x3:
                    cpu->rfile[rA] = cpu->memory[cpu->memory[cpu->pc + 1]];
                    break;
            }
            new_pc ++;
            break;
            
        case 0xD:
            if((int8_t)cpu->rfile[rA] <= 0){
                new_pc = cpu->rfile[rB];
            }
            break;

        case 0xE:
            switch(rB){
    
                case 0x0:
                    cpu->rsp --;
                    cpu->memory[cpu->rsp] = cpu->rfile[rA];
                    break;

                case 0x1:
                    cpu->rfile[rA] = cpu->memory[cpu->rsp];
                    cpu->rsp ++;
                    break;

                case 0x2:
                    cpu->rsp --;
                    cpu->memory[cpu->rsp] = cpu->pc + 2;
                    new_pc = cpu->memory[cpu->pc + 1];

                    break;

                case 0x3:
                    new_pc = cpu->memory[cpu->rsp];
                    cpu->rsp += 1;
                    break;
            }
            break;

        case 0xF:
            cpu->halt = true;
            new_pc = cpu->pc;
            break;
    }
    cpu->pc = new_pc;
}

// display register contents
void register_dump(CPU *cpu){
    printf("Register Values:\n");
    printf("r0: %3u  0x%02X\n", cpu->rfile[0], cpu->rfile[0]);
    printf("r1: %3u  0x%02X\n", cpu->rfile[1], cpu->rfile[1]);
    printf("r2: %3u  0x%02X\n", cpu->rfile[2], cpu->rfile[2]);
    printf("r3: %3u  0x%02X\n", cpu->rfile[3], cpu->rfile[3]);
    printf("\n");
    printf("pc:  %3u  0x%02X\n", cpu->pc, cpu->pc);
    printf("rsp: %3u  0x%02X\n", cpu->rsp, cpu->rsp);
    printf("halt: %s\n", cpu->halt ? "true" : "false");
    printf("\n");
}