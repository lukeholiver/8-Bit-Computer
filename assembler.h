#ifndef ASSEMBLER_H
#define ASSEMBLER_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

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

typedef enum {
    REGISTER,       // 0
    IMMEDIATE,      // 1
    MEM_REGISTER,   // 2
    MEM_IMMEDIATE,  // 3
    PC,             // 4
    INVALID         // 5
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
    INST_BLEZ,      // 12
    INST_PUSH,      // 13
    INST_POP,       // 14
    INST_CALL,      // 15
    INST_RET,       // 16
    INST_HALT,      // 17
    INST_INVALID    // 18
} INSTRUCTION_TYPE;

void parse(char *line, PARSED_LINE *parsed);

void init_instruction(PARSED_LINE *parsed, INSTRUCTION *instruction);

void init_operands(PARSED_LINE *parsed, OPERAND *source, OPERAND *destination);

void type_check(OPERAND *operand);

void value_check(OPERAND *operand);

char *encode_instruction(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination);

void encode_operands(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination, char *buff);

void encode_immediate(OPERAND *source, char *buff);

#endif