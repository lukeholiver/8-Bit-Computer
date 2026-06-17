all: assembler simulator

assembler: assembler.c assembler_main.c
	clang assembler.c assembler_main.c -o assembler

simulator: simulator.c simulator_main.c
	clang simulator.c simulator_main.c -o simulator

clean:
	rm -f assembler simulator