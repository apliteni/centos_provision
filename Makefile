.PHONY: test

CURRENT_BRANCH=$(shell git describe --all --exact-match | sed 's|heads/||g')
RELEASE_VERSION=$(shell cat RELEASE_VERSION)

deploy:
	git tag -f v$(RELEASE_VERSION)
	git push origin $(CURRENT_BRANCH)
	git push origin --tags

test_rbooster:
	ansible-playbook -i hosts-vagrant rbooster.yml --tags=clickhouse
