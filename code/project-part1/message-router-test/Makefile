compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires -p +:.. MessageRouterTest.bsv
	bsc -sim -e mkMessageRouterTest -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -p +:.. -o mkMessageRouterTest

clean:
	rm -rf buildDir mkMessageRouterTest*

.PHONY: compile clean
.DEFAULT_GOAL := compile
