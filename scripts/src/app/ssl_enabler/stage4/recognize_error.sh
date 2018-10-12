#!/usr/bin/env bash

recognize_error() {
  local certbot_log="${1}"
  local key="unknown_error"
  debug "$(print_content_of ${certbot_log})"
  if grep -q '^There were too many requests' "${certbot_log}"; then
    key="too_many_requests"
  else
    local error_detail=$(grep '^    Detail:' "${certbot_log}" 2>/dev/null)
    debug "certbot error detail from ${certbot_log}: ${error_detail}"
    if [[ $error_detail =~ "NXDOMAIN looking up A" ]]; then
      key="wrong_a_entry"
    elif [[ $error_detail =~ "No valid IP addresses found" ]]; then
      key="wrong_a_entry"
    elif [[ $error_detail =~ "Invalid response from" ]]; then
      key="wrong_a_entry"
    fi
  fi
  debug "The error key is ${key}"
  print_translated "certbot_errors.${key}"
}
