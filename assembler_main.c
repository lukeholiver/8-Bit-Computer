#include "assembler.h"

/*
open file -> done
read one line -> done
parse/tokenize that line -> done
encode instruction
append machine code to output buffer
repeat -> kinda done
print final machine code

add line to temp buffer
split string into 3 tokens (instruction, source, destination)
use switch table to filter for correct instruction
write nibble to final buffer
use switch table to filter for correct registers/immediates
write nibble to final buffer
print buffer to stdout

*/

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
    fgets(line, sizeof(line), file_ptr);
    printf("%s\n", line);

    parse(line, &parsed);
    
    // init instruction struct
    init_instruction(&parsed, &instruction);

    // init operand structs
    init_operands(&parsed, &source, &destination);
    
    // printf("Instruction DATA\n");
    // printf("Instruction: %s, type: %d\n", instruction.txt, instruction.type);

    // printf("Source DATA\n");
    // printf("\n");
    // printf("txt: %s, type: %d, value: %d", source.txt, source.type, source.value);
    // printf("\n");

    // printf("Destination DATA\n");
    // printf("\n");
    // printf("txt: %s, type: %d, value: %d", destination.txt, destination.type, destination.value);
    // printf("\n");
    
    char *nibble = encode_instruction(&instruction, &source, &destination);

    // printf("Instruction type: %d\n", instruction.type);
    // printf("Source type: %d\n", source.type);
    // printf("Destination type: %d\n", destination.type);

    printf("%s\n", nibble);
    printf("\n");
        
    fclose(file_ptr);

    return 0;
}