#!/usr/bin/env bash
#





stage3(){
  debug "Starting stage 3: read values from inventory file"
  setup_vars
  read_inventory_file
}
