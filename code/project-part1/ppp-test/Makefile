compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires -p +:.. PPPTest.bsv
	bsc -sim -e mkPPPTest -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -p +:.. -o mkPPPTest

clean:
	rm -rf buildDir mkPPPTest*

.PHONY: compile clean
.DEFAULT_GOAL := compile
