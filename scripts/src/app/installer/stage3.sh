#!/usr/bin/env bash

stage3(){
  debug "Starting stage 3: generate inventory file"
  setup_vars
  read_inventory_file
  get_user_vars
  write_inventory_file
}
