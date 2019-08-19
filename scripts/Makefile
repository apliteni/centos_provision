RELEASE_VERSION ?= $(shell cat ../RELEASE_VERSION)

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

compile: set_release_version compile_site_adder compile_installer compile_ssl_enabler compile_run_command_tester

define compile_template
	cp $(1) $(2)
	bin/postprocess_requires $(2)
	chmod a+x $(2)
endef

set_release_version:
	@echo "Set current release to $(RELEASE_VERSION)"
	@sed -i "s/^RELEASE_VERSION=.*/RELEASE_VERSION='$(RELEASE_VERSION)'/g" src/shared/vars/common.sh

compile_installer:
	$(call compile_template,src/installer.sh.tpl,install.sh)

compile_ssl_enabler:
	$(call compile_template,src/ssl_enabler.sh.tpl,enable-ssl.sh)

compile_site_adder:
	$(call compile_template,src/site_adder.sh.tpl,add-site.sh)

compile_run_command_tester:
	$(call compile_template,src/run_command_tester.sh.tpl,test-run-command.sh)
