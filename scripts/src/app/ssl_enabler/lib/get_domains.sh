#!/usr/bin/env bash

get_domains(){
  (cat "${CERT_DOMAINS_PATH}" 2>/dev/null; join_by " " "${DOMAINS[@]}")
}
