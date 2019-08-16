#!/usr/bin/env bash

read_inventory(){
  detect_inventory_path
  if isset "${DETECTED_INVENTORY_PATH}"; then
    parse_inventory "${DETECTED_INVENTORY_PATH}"
  fi
}

parse_inventory(){
  local file="${1}"
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
