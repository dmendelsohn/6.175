compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires -p +:.. MessageFifoTest.bsv
	bsc -sim -e mkMessageFifoTest -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -p +:.. -o mkMessageFifoTest

clean:
	rm -rf buildDir mkMessageFifoTest*

.PHONY: compile clean
.DEFAULT_GOAL := compile
