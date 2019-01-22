#!/usr/bin/env bash

remove_inventory_file(){
  if [ -f "${INVENTORY_FILE}" ]; then
    debug "Remove ${INVENTORY_FILE}"
    rm -f "${INVENTORY_FILE}"
  fi
}
