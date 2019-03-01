#!/usr/bin/env bash

read_inventory(){
  if is_file_exist "${HOME}/${INVENTORY_FILE}" "no"; then
    read_inventory_file "${HOME}/${INVENTORY_FILE}"
  fi
  if is_file_exist "${INVENTORY_FILE}"; then
    read_inventory_file "${INVENTORY_FILE}"
  fi
}
