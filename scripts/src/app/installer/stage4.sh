#!/usr/bin/env bash
#





stage4(){
  debug "Starting stage 4: generate inventory file"
  if isset "$AUTO_INSTALL"; then
    debug "Skip reading vars from stdin"
  else
    get_user_vars
  fi
  write_inventory_file
}
