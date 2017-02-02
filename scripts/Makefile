test: clean compile
	rspec spec/scripts/ssl_enabler_spec.rb spec/scripts/installer_spec.rb

clean:
	rm -f {install,enable-ssl}.log*

compile: compile_installer compile_ssl_enabler

compile_installer:
	powscript --compile src/installer.pow  > install.sh || true
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' install.sh         # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' install.sh                   # remove unportable cleaning
	sed -i 's/#$$//g' install.sh                                    # remove trailing #
	chmod a+x install.sh

compile_ssl_enabler:
	powscript --compile src/ssl_enabler.pow  > enable-ssl.sh || true
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' enable-ssl.sh      # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' enable-ssl.sh                # remove unportable cleaning
	sed -i 's/#$$//g' enable-ssl.sh                                 # remove trailing #
	chmod a+x enable-ssl.sh
