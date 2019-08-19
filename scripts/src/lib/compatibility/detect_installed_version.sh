#!/usr/bin/env bash

detect_installed_version(){
  local version=""
  detect_inventory_path
  if isset "${DETECTED_INVENTORY_PATH}"; then
    version=$(grep "^installer_version=" ${DETECTED_INVENTORY_PATH} | sed s/^installer_version=//g)
  fi
  if empty "$version"; then
    version="0.9"
  fi
  echo "$version"
}
