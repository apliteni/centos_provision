test: compile
	rspec spec

compile: compile_installer compile_ssl_enabler

compile_installer:
	powscript --compile src/installer.pow  > install.sh
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' install.sh         # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' install.sh                   # remove unportable cleaning
	chmod a+x install.sh

compile_ssl_enabler:
	powscript --compile src/ssl_enabler.pow  > enable-ssl.sh
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' enable-ssl.sh      # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' enable-ssl.sh                # remove unportable cleaning
	chmod a+x enable-ssl.sh
