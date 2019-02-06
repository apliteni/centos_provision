#!/usr/bin/env bash
SUBDOMAIN_REGEXP="[[:alnum:]-]+"
DOMAIN_REGEXP="(${SUBDOMAIN_REGEXP}\.)+[[:alpha:]]${SUBDOMAIN_REGEXP}"

validate_domain(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_REGEXP}$ ]]
}
