#!/usr/bin/env bash
#





stage3(){
  debug "Starting stage 3: read values from inventory file"
  read_inventory
  setup_vars
  if isset "$RECONFIGURE"; then
    upgrade_packages
  fi
}
