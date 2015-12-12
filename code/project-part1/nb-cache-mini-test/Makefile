compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires -p +:.. NBCacheMiniTest.bsv
	bsc -sim -e mkNBCacheMiniTest -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -p +:.. -o mkNBCacheMiniTest

clean:
	rm -rf buildDir mkNBCacheMiniTest*

.PHONY: compile clean
.DEFAULT_GOAL := compile
