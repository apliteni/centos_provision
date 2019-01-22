all: clean compile test

installer: compile_installer test_installer

site_adder: compile_site_adder test_site_adder

ssl_enabler: compile_ssl_enabler test_ssl_enabler

run_command_tester: compile_run_command_tester test_run_command_tester

test: 
	rspec spec

test_site_adder:
	rspec spec/scripts/site_adder_spec.rb

test_ssl_enabler:
	rspec spec/scripts/ssl_enabler_spec.rb

test_installer:
	rspec spec/scripts/installer_spec.rb

test_run_command_tester:
	rspec spec/scripts/run_command_tester_spec.rb

clean:
	rm -f *.log*

compile: compile_site_adder compile_installer compile_ssl_enabler compile_run_command_tester

define compile_powscript
	bin/powscript --compile src/$(1) > $(2) || true
	sed -i 's|#!/bin/bash|#!/usr/bin/env bash|g' $(2)         # portable shebang line
	sed -i '/# cleanup tmp files/,+4d' $(2)                   # remove unportable cleaning
	sed -i 's/#$$//g' $(2)                                    # remove trailing #
	bin/postprocess_requires.rb $(2)
	chmod a+x $(2)
endef

compile_chunks:
	@echo Compiling sources
	@for pow_script in $$(find src/{app,lib,shared} -name '*.pow'); do \
	  bash_script=$${pow_script/pow/sh}; \
	  if [[ -f $$bash_script && "$$(stat -c %y $$pow_script)" == "$$(stat -c %y $$bash_script)" ]]; \
	  then \
	    printf "."; \
	  else \
	    printf "o"; \
	    bin/powscript --compile --sourceable $$pow_script \
	        | sed -r -e '2,23d' -e '/^(empty|isset|on|values|last) /,/^}/d' -e '1c#!/usr/bin/env bash' \
	        > $$bash_script; \
	    touch -amr $$pow_script $$bash_script; \
	  fi \
	done
	@echo

compile_installer: compile_chunks
	$(call compile_powscript,installer.pow,install.sh)

compile_ssl_enabler: compile_chunks
	$(call compile_powscript,ssl_enabler.pow,enable-ssl.sh)

compile_site_adder: compile_chunks
	$(call compile_powscript,site_adder.pow,add-site.sh)

compile_run_command_tester: compile_chunks
	$(call compile_powscript,run_command_tester.pow,test-run-command.sh)
