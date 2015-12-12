# This makefile is used to compile all the example c and assembly smips
# programs. To add a new assembly program, just include the assembly source
# in src/assembly/. To add a new c program, add the source in a folder within
# src/ and add the necessary target and rules to this makefile.
#
# To get the makefile to work, unpack smips-gcc.tar.gz in SMIPS_DIR. The smips
# compiler is a 32-bit executable so you may need 32-bit libraries for your
# computer to get it to work.
SMIPS_DIR=/mit/6.175/smips-gcc

CC=$(SMIPS_DIR)/bin/smips-gcc -B$(SMIPS_DIR)/lib/gcc-lib/smips/egcs-2.90.29/ -B/$(SMIPS_DIR)/bin/ -B/$(SMIPS_DIR)/smips/bin/ -G 0

# Single-core targets
benchmarks:=mandelbrot malloc median multiply qsort towers vvadd
assembly:=$(patsubst src/assembly/%.S,%,$(wildcard src/assembly/*.S))

benchmarks_exe:=$(patsubst %,build/%.bench.exe,$(benchmarks))
assembly_exe:=$(patsubst %,build/%.asm.exe,$(assembly))

benchmarks_dump:=$(patsubst %,build/%.bench.dump,$(benchmarks))
assembly_dump:=$(patsubst %,build/%.asm.dump,$(assembly))

benchmarks_vmh:=$(patsubst %,build/%.bench.vmh,$(benchmarks))
assembly_vmh:=$(patsubst %,build/%.asm.vmh,$(assembly))

# Multicore targets
mc_benchmarks:=hello incrementers incrementers_atomic mc_median mc_multiply mc_multiply2 mc_print mc_vvadd
mc_assembly:=$(patsubst src/mc_assembly/%.S,%,$(wildcard src/mc_assembly/*.S))

mc_benchmarks_exe:=$(patsubst %,build/%.mc_bench.exe,$(mc_benchmarks))
mc_assembly_exe:=$(patsubst %,build/%.mc_asm.exe,$(mc_assembly))

mc_benchmarks_dump:=$(patsubst %,build/%.mc_bench.dump,$(mc_benchmarks))
mc_assembly_dump:=$(patsubst %,build/%.mc_asm.dump,$(mc_assembly))

mc_benchmarks_vmh:=$(patsubst %,build/%.mc_bench.vmh,$(mc_benchmarks))
mc_assembly_vmh:=$(patsubst %,build/%.mc_asm.vmh,$(mc_assembly))


all: $(benchmarks_vmh) $(assembly_vmh) $(mc_benchmarks_vmh) $(mc_assembly_vmh)

build/malloc.bench.exe: src/malloc/malloc.c
build/mandelbrot.bench.exe: src/Mandelbrot/mandelbrot.c
build/median.bench.exe: src/median/median.c src/median/median_main.c
build/multiply.bench.exe: src/multiply/multiply.c src/multiply/multiply_main.c
build/print.bench.exe: src/print/main.c
build/qsort.bench.exe: src/qsort/qsort_main.c
build/towers.bench.exe: src/towers/towers_main.c
build/vvadd.bench.exe: src/vvadd/vvadd_main.c

build/hello.mc_bench.exe: src/hello/hello_main.c
build/incrementers.mc_bench.exe: src/incrementers/incrementers_main.c
build/incrementers_atomic.mc_bench.exe: src/incrementers_atomic/incrementers_atomic_main.c
build/mc_median.mc_bench.exe: src/mc_median/median.c src/mc_median/mc_median_main.c
build/mc_multiply.mc_bench.exe: src/mc_multiply/multiply.c src/mc_multiply/mc_multiply_main.c
build/mc_multiply2.mc_bench.exe: src/mc_multiply2/multiply.c src/mc_multiply2/mc_multiply2_main.c
build/mc_print.mc_bench.exe: src/mc_print/main.c
build/mc_vvadd.mc_bench.exe: src/mc_vvadd/mc_vvadd_main.c 

$(assembly_exe): build/%.asm.exe: src/assembly/%.S
	mkdir -p build
	$(CC) -static -O2 -nostdlib -nostartfiles -Wa,-O0 -Wl,-Ttext=0x1000,-emain $^ -o $@

$(benchmarks_exe): build/%.bench.exe:
	mkdir -p build
	$(CC) -static -O2 -nostdlib -nostartfiles -Wa,-O0 -Wl,-Ttext=0x1000,-e__start lib/start.S lib/print.c lib/cop.c lib/lock.c $^ -o $@

$(mc_assembly_exe): build/%.mc_asm.exe: src/mc_assembly/%.S
	mkdir -p build
	$(CC) -static -O2 -nostdlib -nostartfiles -Wa,-O0 -Wl,-Ttext=0x1000,-emain $^ -o $@

$(mc_benchmarks_exe): build/%.mc_bench.exe:
	mkdir -p build
	$(CC) -static -O2 -nostdlib -nostartfiles -Wa,-O0 -Wl,-Ttext=0x1000,-e__mc_start lib/mc_start.S lib/print.c lib/cop.c lib/lock.c $^ -o $@

%.dump: %.exe
	$(SMIPS_DIR)/bin/smips-objdump --disassemble-all --disassemble-zeroes $< > $@

%.vmh: %.dump
	$(SMIPS_DIR)/bin/objdump2vmh.pl $< $@

clean:
	-rm -rf build

.INTERMEDIATE: $(benchmarks_exe) $(assembly_exe) $(mc_benchmarks_exe) $(mc_assembly_exe)
