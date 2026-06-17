#ifndef ASSEMBLER_H
#define ASSEMBLER_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct {
    char *instruction;
    char *source;
    char *destination;
} PARSED_LINE;

typedef struct {
    char *txt;
    int type;
    int subcode;
} INSTRUCTION;

typedef struct {
    char *txt;
    int type;
    int value;
} OPERAND;

typedef struct {
    char txt[256];
    uint8_t address;
} LABEL;

typedef enum {
    REGISTER,       // 0
    IMMEDIATE,      // 1
    MEM_REGISTER,   // 2
    MEM_IMMEDIATE,  // 3
    PC,             // 4
    RSP,            // 5
    LABEL_ADDR,     // 6
    INVALID         // 7
} OPERAND_TYPE;

typedef enum {
    INST_NEG,       // 0
    INST_BNOT,      // 1
    INST_LNOT,      // 2
    INST_MOV,       // 3
    INST_ADD,       // 4
    INST_SUB,       // 5
    INST_MUL,       // 6
    INST_SHL,       // 7
    INST_SHR,       // 8
    INST_AND,       // 9
    INST_OR,        // 10
    INST_XOR,       // 11
    INST_JGT,       // 12
    INST_JLT,       // 13
    INST_JE,        // 14
    INST_JNE,       // 15
    INST_PUSH,      // 16
    INST_POP,       // 17
    INST_JMP,       // 18
    INST_CALL,      // 19
    INST_RET,       // 20
    INST_HALT,      // 21
    INST_LABEL,     // 22
    INST_INVALID    // 23
} INSTRUCTION_TYPE;

extern bool error_flag;
extern int address;
extern int label_index;
extern LABEL labels[256];

void parse(char *line, PARSED_LINE *parsed);

void init_instruction(PARSED_LINE *parsed, INSTRUCTION *instruction);

void init_operands(PARSED_LINE *parsed, OPERAND *source, OPERAND *destination);

void type_check(OPERAND *operand);

void value_check(OPERAND *operand);

char *encode_instruction(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination);

void encode_operands(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination, char *buff);

void encode_immediate(OPERAND *source, char *buff);

void init_label(INSTRUCTION *instruction);

#endif