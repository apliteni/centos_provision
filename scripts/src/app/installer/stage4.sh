#!/usr/bin/env bash

stage4(){
  debug "Starting stage 4: generate inventory file"
  get_user_vars
  write_inventory_file
}
