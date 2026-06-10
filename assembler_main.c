#include "assembler.h"

int main(int argc, char *argv[]){

    // confirm recieved file
    if(argc < 2){
        printf("Please input ./a.out filename.txt");
        return 1;
    }

    // open file
    FILE *file_ptr = fopen(argv[1], "r");
    if(file_ptr == NULL){
        printf("File failed to open");
        return 1;
    }

    // Variables
    char line[256] = {0};
    PARSED_LINE parsed;
    INSTRUCTION instruction;
    OPERAND source;
    OPERAND destination;

    // read line by line
    while(fgets(line, sizeof(line), file_ptr)){

        // parse line into tokens
        parse(line, &parsed);
        
        // init instruction struct
        init_instruction(&parsed, &instruction);

        // init operand structs
        init_operands(&parsed, &source, &destination);

        // encode line
        char *inst_nibble = encode_instruction(&instruction, &source, &destination);
        char *ops_nibble = encode_operands(&instruction, &source, &destination);
        char *imm_byte = encode_immediate(&source);
        
        // print byte(s) to stdout
        printf("%s%s%s", inst_nibble, ops_nibble, imm_byte);
    }

    fclose(file_ptr);

    return 0;
}