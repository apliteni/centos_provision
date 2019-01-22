#!/usr/bin/env bash


validate_ip(){
  local value="${1}"
  [[ "$value" =~  ^[[:digit:]]+(\.[[:digit:]]+){3}$ ]] && valid_ip_segments "$value"
}


valid_ip_segments(){
  local ip="${1}"
  local segments="${ip//./ }"
  for segment in "$segments"; do
    if ! valid_ip_segment $segment; then
      return ${FAILURE_RESULT}
    fi
  done
}

valid_ip_segment(){
  local ip_segment="${1}"
  [ $ip_segment -ge 0 ] && [ $ip_segment -le 255 ]
}
