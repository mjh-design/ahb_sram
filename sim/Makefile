.PHONY:compile sim clean

OUTPUT = simv

VCS = vcs -full64 -sverilog + v2k -debug_all -o ${OUTPUT} -l compile.log

compile:
		${VCS} -f flist.f

clean:
		rm -rf ./csrc *.daidir *.log simv* *.key

