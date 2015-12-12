compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires -p +:.. NBCacheTest.bsv
	bsc -sim -e mkNBCacheTest -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -p +:.. -o mkNBCacheTest

clean:
	rm -rf buildDir mkNBCacheTest*

.PHONY: compile clean
.DEFAULT_GOAL := compile
