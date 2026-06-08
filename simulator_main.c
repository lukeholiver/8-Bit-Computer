#include "simulator.h"

int main(int argc, char *argv[]){

        // create CPU
        CPU cpu;
        init_cpu(&cpu);
        printf("CPU Created\n");

        // check for valid program
        if(!safety_check(argv[1])){
                printf("Invalid Program");
                return 0;
        }
        printf("Program Validated\n");

        // load memory
        load_memory(&cpu, argv[1]);
        printf("Memory Loaded\n");

        // run program
        printf("Running Program\n");
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