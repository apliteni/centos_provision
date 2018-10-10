#!/usr/bin/env bash

recognize_error() {
  local certbot_log="${1}"
  local key="unknown_error"
  local error_detail=$(grep '^    Detail:' "${certbot_log}" 2>/dev/null)
  debug "certbot error detail from ${certbot_log}: ${error_detail}"
  if [[ $error_detail =~ "NXDOMAIN looking up A" ]]; then
    key="looking_up_a"
  elif [[ $error_detail =~ "Invalid response from" ]]; then
    key="a_points_wrong_ip"
  fi
  debug "The error key is ${key}"
  echo $key
}
