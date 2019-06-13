#!/usr/bin/env bash

assert_has_enough_ram(){
  if is_file_exist /proc/meminfo no; then
    memsize_kb=$(cat /proc/meminfo | head -n1 | awk '{print $2}')
    if (( memsize_kb -lt 2000000 )); then
      fail "$(translate errors.not_enough_ram)"
    fi
  fi
}
