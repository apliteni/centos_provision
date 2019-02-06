#!/usr/bin/env bash
DOMAIN_LIST_REGEXP="${DOMAIN_REGEXP}(,${DOMAIN_REGEXP})*"

validate_domains_list(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_LIST_REGEXP}$ ]]
}
