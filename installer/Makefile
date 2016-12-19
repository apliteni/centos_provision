test: compile
	rspec spec

compile:
	powscript --compile bin/install.pow | sed "s/#!\/bin\/bash/#!\/usr\/bin\/env bash/g" > bin/install.sh
