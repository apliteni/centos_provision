all: clean compile test

installer: compile_installer test_installer

site_adder: compile_site_adder test_site_adder

ssl_enabler: compile_ssl_enabler test_ssl_enabler

test: 
	rspec spec

test_site_adder:
	rspec spec/scripts/site_adder_spec.rb

test_ssl_enabler:
	rspec spec/scripts/ssl_enabler_spec.rb

test_installer:
	rspec spec/scripts/installer_spec.rb

clean:
	rm -f *.log*

compile: compile_site_adder compile_installer compile_ssl_enabler

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

compile_site_adder:
	powscript --compile src/site_adder.pow  > add-site.sh || true
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' add-site.sh      # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' add-site.sh                # remove unportable cleaning
	sed -i 's/#$$//g' add-site.sh                                 # remove trailing #
	chmod a+x add-site.sh
