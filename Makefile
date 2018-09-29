.PHONY: test

test_rbooster:
	ansible-playbook -i hosts-vagrant rbooster.yml --tags=clickhouse