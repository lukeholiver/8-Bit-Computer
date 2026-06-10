#include "simulator.h"

int main(int argc, char *argv[]){

        // create CPU
        CPU cpu;
        init_cpu(&cpu);

        char program[513];

        if(argc >= 2){
                strncpy(program, argv[1], sizeof(program) - 1);
                program[sizeof(program) - 1] = '\0';
        }
        else{
                if(fgets(program, sizeof(program), stdin) == NULL){
                        printf("No program received\n");
                        return 1;
                }

                program[strcspn(program, "\n")] = '\0';
        }

        // check for valid program
        if(!safety_check(program)){
                printf("Invalid Program");
                return 0;
        }

        // load memory
        load_memory(&cpu, program);

        // run program
        while(!cpu.halt){
                uint8_t instruction = fetch_instruction(&cpu);
                execute_instruction(&cpu, instruction);
        }

        // display register contents
        printf("Program Completed\n");
        printf("\n");
        register_dump(&cpu);

        return 0;
}