test: compile
	rspec spec

compile:
	powscript --compile src/install.pow  > install.sh
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' install.sh         # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' install.sh                   # remove unportable cleaning
	chmod a+x install.sh
