#!/usr/bin/env bash

read_inventory(){
  paths=("${INVENTORY_FILE}" /root/.keitaro/installer_config .keitaro/installer_config /root/hosts.txt hosts.txt)
  for inventory_path in "${paths[@]}"; do
    if [[ -f "${inventory_path}" ]]; then
      parse_inventory_file "${inventory_path}"
      return
    fi
  done
  debug "Inventory file not found"
}

parse_inventory_file(){
  local file="${1}"
  INVENTORY_PARSED="${file}"
  debug "Found inventory file ${file}, read defaults from it"
  while IFS="" read -r line; do
    if [[ "$line" =~ = ]]; then
      parse_line_from_inventory_file "$line"
    fi
  done < "${file}"
}


parse_line_from_inventory_file(){
  local line="${1}"
  IFS="=" read var_name value <<< "$line"
  if [[ "$var_name" != 'db_restore_path' ]]; then
    if empty "${VARS[$var_name]}"; then
      VARS[$var_name]=$value
      debug "# read $var_name from inventory"
    else
      debug "# $var_name is set from options, skip inventory value"
    fi
    debug "  "$var_name"=${VARS[$var_name]}" 'light.blue'
  fi
}
