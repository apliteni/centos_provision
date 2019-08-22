CURRENT_BRANCH=$(shell git branch --show-current)
RELEASE_VERSION=$(shell cat RELEASE_VERSION)

error:
	@echo "Please choose one of the following target: release, test_rbooster"
	@exit 1

release:
	git tag -f v$(RELEASE_VERSION)
	git push origin -f --tags
	git push origin -f $(CURRENT_BRANCH):release-$(RELEASE_VERSION)

test_rbooster:
	ansible-playbook -i hosts-vagrant rbooster.yml --tags=clickhouse
