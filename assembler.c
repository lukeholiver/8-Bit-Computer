#include "assembler.h"

// error flag bool
bool error_flag = false;

// 1st-pass-variables
int address = 0;
int label_index = 0;
LABEL labels[256] = {0};

// splits an assembly line into tokens
void parse(char *line, PARSED_LINE *parsed){

    line[strcspn(line, "\r\n")] = '\0';

    parsed->instruction = strsep(&line, " ");

    if(line == NULL){   // check for zero operand instructions
        parsed->source = NULL;
        parsed->destination = NULL;
        return;
    }

    parsed->source = strsep(&line, ",");

    if(line == NULL){   // check for single operand instructions
        parsed->destination = NULL;
        return;
    }

    parsed->destination = &line[1];
}

// initializes instruction struct
void init_instruction(PARSED_LINE *parsed, INSTRUCTION *instruction){

    // init instruction txt field
    instruction->txt = parsed->instruction;
    char *tmp = instruction->txt;
    instruction->subcode = -1;

    // init instruction_type field
    if(strcmp(tmp, "neg") == 0){
        instruction->type = INST_NEG;
    }
    else if(strcmp(tmp, "bnot") == 0){
        instruction->type = INST_BNOT;
    }
    else if(strcmp(tmp, "lnot") == 0){
        instruction->type = INST_LNOT;
    }
    else if(strcmp(tmp, "mov") == 0){
        instruction->type = INST_MOV;
    }
    else if(strcmp(tmp, "add") == 0){
        instruction->type = INST_ADD;
    }
    else if(strcmp(tmp, "sub") == 0){
        instruction->type = INST_SUB;
    }
    else if(strcmp(tmp, "mul") == 0){
        instruction->type = INST_MUL;
    }
    else if(strcmp(tmp, "shl") == 0){
        instruction->type = INST_SHL;
    }
    else if(strcmp(tmp, "shr") == 0){
        instruction->type = INST_SHR;
    }
    else if(strcmp(tmp, "and") == 0){
        instruction->type = INST_AND;
    }
    else if(strcmp(tmp, "or") == 0){
        instruction->type = INST_OR;
    }
    else if(strcmp(tmp, "xor") == 0){
        instruction->type = INST_XOR;
    }
    else if(strcmp(tmp, "jgt") == 0){
        instruction->type = INST_JGT;
    }
    else if(strcmp(tmp, "jlt") == 0){
        instruction->type = INST_JLT;
    }
    else if(strcmp(tmp, "je") == 0){
        instruction->type = INST_JE;
    }
    else if(strcmp(tmp, "jne") == 0){
        instruction->type = INST_JNE;
    }
    else if(strcmp(tmp, "push") == 0){
        instruction->type = INST_PUSH;
    }
    else if(strcmp(tmp, "pop") == 0){
        instruction->type = INST_POP;
    }
    else if(strcmp(tmp, "jmp") == 0){
        instruction->type = INST_JMP;
    }
    else if(strcmp(tmp, "call") == 0){
        instruction->type = INST_CALL;
    }
    else if(strcmp(tmp, "ret") == 0){
        instruction->type = INST_RET;
    }
    else if(strcmp(tmp, "halt") == 0){
        instruction->type = INST_HALT;
    }
    else if(strcmp(&tmp[strlen(tmp) - 1], ":") == 0){ // check for :
        instruction->type = INST_LABEL;
    }
    else{
        instruction->type = INST_INVALID;
        error_flag = true;
    }
}

// initializes operand structs
void init_operands(PARSED_LINE *parsed, OPERAND *source, OPERAND *destination){
    
    // init operand txt fields
    source->txt = parsed->source;
    destination->txt = parsed->destination;

    // init operand type fields
    type_check(source);
    type_check(destination);

    // init operand value fields
    value_check(source);
    value_check(destination);

}

// determines the type of an operand
void type_check(OPERAND *operand){

    if(operand->txt == NULL || operand->txt[0] == '\0'){
        operand->type = INVALID;
        return;
    }

    size_t len = strlen(operand->txt);

    if(operand->txt[0] == '%'){
        operand->type = REGISTER;
        return;
    }
    else if(strcmp(operand->txt, "pc") == 0){
        operand->type = PC;
        return;
    }
    else if(strcmp(operand->txt, "rsp") == 0){
        operand->type = RSP;
        return;
    }
    else if(operand->txt[0] == '$'){
        operand->type = IMMEDIATE;
        return;
    } 
    else if(len == 5 && 
            operand->txt[0] == '(' && 
            operand->txt[len - 1] == ')') {

        if(operand->txt[1] == '%'){
           operand->type = MEM_REGISTER;
           return;
        }
        else if(operand->txt[1] == '$'){
            operand->type = MEM_IMMEDIATE;
            return;
        }
        else{
           operand->type = INVALID;
           return;
        }
    }
    else{
        for(int i = 0; i < label_index; i++){
            if(strcmp(labels[i].txt, operand->txt) == 0){
                operand->type = IMMEDIATE;
                operand->value = labels[i].address;
                return;
            }
        }
    }

    // safety-net for unresolved labels
    error_flag = true;
    operand->type = LABEL_ADDR;

}

// determines the value of an operand
void value_check(OPERAND *operand){

    if(operand->type == REGISTER){
        char *num_value = &operand->txt[2];
        operand->value = (int) strtol(num_value, NULL, 16);
        if(operand->value < 0 || operand->value > 3){
            operand->type = INVALID;
            error_flag = true;
        }
    }
    else if(operand->type == IMMEDIATE && operand->txt[0] == '$'){
        char *num_value = &operand->txt[1];
        operand->value = (int) strtol(num_value, NULL, 16);
    }    
    else if(operand->type == MEM_REGISTER){
        char *num_value = &operand->txt[3];
        operand->value = (int) strtol(num_value, NULL, 16);
        if(operand->value < 0 || operand->value > 3){
            operand->type = INVALID;
            error_flag = true;
        }
    }
    else if(operand->type == MEM_IMMEDIATE){
        char *num_value = &operand->txt[2];
        operand->value = (int) strtol(num_value, NULL, 16);
    }
}

// // convert instruction to nibble
char *encode_instruction(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination){

    switch(instruction->type){
    
        case INST_NEG:
            instruction->subcode = 0;
            return "0";

        case INST_BNOT:
            instruction->subcode = 1;
            return "0";

        case INST_LNOT:
            instruction->subcode = 2;
            return "0";

        case INST_MOV: // need to look at

            if(source->type == PC && destination->type == REGISTER){
                instruction->subcode = 3;
                return "0";
            }
            else if(source->type == REGISTER && destination->type == REGISTER){
                return "1";
            }
            else if(source->type == MEM_REGISTER && destination->type == REGISTER){
                return "A";
            }
            else if(source->type == REGISTER && destination->type == MEM_REGISTER){
                return "B";
            }
            else if(source->type == IMMEDIATE && destination->type == REGISTER){
                instruction->subcode = 0;
                return "C";
            }
            else if(source->type == MEM_IMMEDIATE && destination->type == REGISTER){
                instruction->subcode = 3;
                return "C";
            }
            else{   // error detected
                error_flag = true;
                return "F";
            }

        case INST_ADD:

            switch(source->type){

                case REGISTER:
                    return "2";

                case IMMEDIATE:
                    instruction->subcode = 1;
                    return "C";
                default:    // error detected
                    error_flag = true;
                    return "F";
            }

        case INST_SUB:
            return "3";

        case INST_MUL:
            return "4";

        case INST_SHL:
            return "5";

        case INST_SHR:
            return "6";

        case INST_AND:
            return "7";
            
        case INST_OR:
            return "8";

        case INST_XOR:
            return "9";
            
        case INST_JGT:
            instruction->subcode = 0;
            return "D";

        case INST_JLT:
            instruction->subcode = 1;
            return "D";

        case INST_JE:
            instruction->subcode = 2;
            return "D";

        case INST_JNE:
            instruction->subcode = 3;
            return "D";
    
        case INST_PUSH:
            
            switch(source->type){

                case REGISTER:
                    instruction->subcode = 0;
                    return "E";

                case IMMEDIATE:
                    instruction->subcode = 1;
                    return "E";

                default:    // error detected
                    error_flag = true;
                    return "F";
            }

        case INST_POP:
            instruction->subcode = 2;
            return "E";

        case INST_JMP:
            instruction->subcode = 0;
            return "F";
            
        case INST_CALL:
            instruction->subcode = 1;
            return "F";

        case INST_RET:
            instruction->subcode = 2;
            return "F";

        case INST_HALT:
            instruction->subcode = 3;
            return "F";

        case INST_INVALID: // invalid instruction stops program
            return "F";    // error flag already set in init_instruction()

        default: // so compiler doesn't have a stroke
            return "F";
    }   
}

// convert operands to nibble
void encode_operands(INSTRUCTION *instruction, OPERAND *source, OPERAND *destination, char *buff){

    int rA = 0;
    int rB = 0;

    // source: register, destination: register
    if(source->type == REGISTER && destination->type == REGISTER){
        rA = destination->value;
        rB = source->value;
    }

    // source: mem_register, destination: register
    else if(source->type == MEM_REGISTER && destination->type == REGISTER){
        rA = destination->value;
        rB = source->value;
    }

    // source: register, destination: mem_register
    else if(source->type == REGISTER && destination->type == MEM_REGISTER){
        rA = source->value;
        rB = destination->value;
    }

    // source: register, subcode
    else if(source->type == REGISTER && instruction->subcode >= 0){
        rA = source->value;
        rB = instruction->subcode;
    }
    
    // destination: register, subcode
    else if(destination->type == REGISTER && instruction->subcode >= 0){
        rA = destination->value;
        rB = instruction->subcode;
    }
    
    // no registers, subcode
    else if(destination->type != REGISTER && source->type != REGISTER && instruction->subcode >= 0){
        rA = 0;
        rB = instruction->subcode;
    }

    // halt or ret
    else{
        // check for instructions with no operands
        if(instruction->type != INST_HALT && instruction->type != INST_RET){
            error_flag = true;
        }
        rA = 0;
        rB = instruction->subcode;
    }

    char hex[] = "0123456789ABCDEF"; 
    uint8_t nibble = (uint8_t) (rA * 4 + rB);

    buff[0] = hex[nibble];
    buff[1] = '\0';

    return;
}

// convert immediate to byte
void encode_immediate(OPERAND *source, char *buff){

    if(source->type == IMMEDIATE || source->type == MEM_IMMEDIATE){
            if(source->value >= 0 && source->value <= 255){
                snprintf(buff, 3, "%02X", source->value);
            }
            else{
                error_flag = true;
                buff[0] = '\0';
            }
    }
    else{
        buff[0] = '\0';
    }
}

// initalizes label struct
void init_label(INSTRUCTION *instruction){

    // copy label text and remove colon
    strncpy(labels[label_index].txt, instruction->txt, sizeof(labels[label_index].txt));
    labels[label_index].txt[strlen(labels[label_index].txt) - 1] = '\0';

    // set label address and increment index
    labels[label_index].address = address;
    label_index ++;

}