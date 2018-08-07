.PHONY: test

test_clickhouse:
	ansible-playbook -i hosts-vagrant clickhouse.yml --tags=clickhouse