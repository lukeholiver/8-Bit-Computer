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
        printf("File failed to open\n");
        return 1;
    }

    // Variables
    char line[256] = {0};
    char line_copy[256];
    char ops_buff[2];
    char imm_buff[3];
    int line_num = 0;

    PARSED_LINE parsed;
    INSTRUCTION instruction;
    OPERAND source;
    OPERAND destination;

    // 1st pass
    while(fgets(line, sizeof(line), file_ptr)){

        // skip if comment or empty line
        if(line[0] == '\n' || (line[0] == '/' && line[1] == '/')){
            continue;
        }

        // copy line string
        strncpy(line_copy, line, sizeof(line_copy));
        line_copy[255] = '\0';

        // parse line into tokens
        parse(line_copy, &parsed);
        
        // init instruction struct
        init_instruction(&parsed, &instruction);

        // init operand structs
        init_operands(&parsed, &source, &destination);

        // check for label
        if(instruction.type == INST_LABEL){

            // init label struct
            init_label(&instruction);
            continue;
        }

        else if(instruction.type != INST_INVALID && instruction.type != INST_LABEL){
            if(source.type == IMMEDIATE || source.type == MEM_IMMEDIATE || source.type == LABEL_ADDR){
                address += 2;
            }
            else{
                address += 1;
            }
        }
    }

    // reset file pointer and error flag
    rewind(file_ptr);
    error_flag = false;

    // 2nd pass
    while(fgets(line, sizeof(line), file_ptr)){

        // increment line number
        line_num++;

        // skip if comment or empty line
        if(line[0] == '\n' || (line[0] == '/' && line[1] == '/')){
            continue;
        }

        // copy line string
        strncpy(line_copy, line, sizeof(line_copy));
        line_copy[255] = '\0';

        // parse line into tokens
        parse(line_copy, &parsed);
        
        // init instruction struct
        init_instruction(&parsed, &instruction);

        // check for label
        if(instruction.type == INST_LABEL){
            continue;
        }

        // init operand structs
        init_operands(&parsed, &source, &destination);

        // encode line
        char *inst_nibble = encode_instruction(&instruction, &source, &destination); // safe returning literals
        encode_operands(&instruction, &source, &destination, ops_buff);
        encode_immediate(&source, imm_buff);

        // error check
        if(error_flag){
            fprintf(stderr, "Error on line %d: %s\n", line_num, line);
            fclose(file_ptr);
            return 1;
        }
        
        // print byte(s) to stdout
        printf("%s%s%s", inst_nibble, ops_buff, imm_buff);
    }

    fclose(file_ptr);

    return 0;
}
