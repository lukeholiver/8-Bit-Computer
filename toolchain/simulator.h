#ifndef SIMULATOR_H
#define SIMULATOR_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>

/* CPU Struct */

typedef struct {

    uint8_t rfile[4];
    uint8_t pc;
    uint8_t rsp;
    uint8_t memory[256];
    bool halt;

} CPU;

/* Function Prototypes */

void init_cpu(CPU *cpu);

bool safety_check(char *program);

void load_memory(CPU *cpu, char *program);

uint8_t fetch_instruction(const CPU *cpu);

void execute_instruction(CPU *cpu, uint8_t instruction);

void register_dump(CPU *cpu);

#endif