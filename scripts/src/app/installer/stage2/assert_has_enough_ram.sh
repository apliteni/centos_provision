#!/usr/bin/env bash
MIN_SIZE_KB=2000000

assert_has_enough_ram(){
  debug "Checking RAM size"
  if is_file_exist /proc/meminfo no; then
    local memsize_kb=$(cat /proc/meminfo | head -n1 | awk '{print $2}')
    if [[ "$memsize_kb" -lt "$MIN_SIZE_KB" ]]; then
      debug "RAM size ${current_size_kb}kb is less than ${MIN_SIZE_KB}, raising error"
      fail "$(translate errors.not_enough_ram)"
    else
      debug "RAM size ${current_size_kb}kb is greater than ${MIN_SIZE_KB}, continuing"
    fi
  fi
}
