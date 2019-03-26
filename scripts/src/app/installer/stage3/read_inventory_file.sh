#!/usr/bin/env bash

read_inventory_file(){
  local file="${1}"
  if [ -f "${file}" ]; then
    debug "Inventory file found, read defaults from it"
    while IFS="" read -r line; do
      parse_line_from_inventory_file "$line"
    done < "${file}"
  else
    debug "Inventory file not found"
  fi
}


parse_line_from_inventory_file(){
  local line="${1}"
  if [[ "$line" =~ = ]]; then
    IFS="=" read var_name value <<< "$line"
    VARS[$var_name]=$value
    debug "  "$var_name"=${VARS[$var_name]}" 'light.blue'
  fi
}
