#include "assembler.h"

int main(int argc, char *argv[]){

    // confirm recieved file
    if(argc < 2){
        fprintf(stderr, "Please input ./a.out filename.txt\n");
        return 1;
    }

    // open file
    FILE *file_ptr = fopen(argv[1], "r");
    if(file_ptr == NULL){
        fprintf(stderr, "File failed to open\n");
        return 1;
    }

    // Variables
    char line[256] = {0};
    char line_copy[256];
    char ops_buff[2];
    char imm_buff[3];
    char program_buffer[PROGRAM_BUFFER_SIZE] = {0};
    char *cursor = program_buffer;  // used for snprintf
    int line_num = 0;
    bool error_detected = false;

    size_t remaining = sizeof(program_buffer);

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

        // check for label, confirm no duplicates/overflow
        if(instruction.type == INST_LABEL){
            if(!init_label(&instruction)){
                fclose(file_ptr);
                return 1;
            }
            continue;
        }

        else if(instruction.type != INST_INVALID && instruction.type != INST_LABEL){
            if(source.type == IMMEDIATE || source.type == MEM_IMMEDIATE ||
               source.type == LABEL_ADDR || destination.type == LABEL_ADDR ||
               destination.type == IMMEDIATE){
                address += 2;
            }
            else{
                address += 1;
            }
        }
    }

    // check for overflow
    if(address > 256){
        fprintf(stderr, "Error: program requires %d bytes, exceeds 256 byte memory limit.\n", address);
        fclose(file_ptr);
        return 1;
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
        encode_immediate(&source, &destination, imm_buff);

        // load bytes into program buffer
        int written = snprintf(cursor, remaining, "%s%s%s", inst_nibble, ops_buff, imm_buff);
        cursor += written;
        remaining -= written;

        // error check
        if(error_flag){
            fprintf(stderr, "Error on line %d: %s\n", line_num, line);
            error_detected = true;
            error_flag = false;
        }

    }

    // print to stdout
    if(!error_detected){
        printf("%s", program_buffer);
    }

    // print to stderr
    else{
        fprintf(stderr, "Assembly failed, errors detected.\n");
    }

    // close and return
    fclose(file_ptr);
    return error_detected ? 1 : 0;

}
