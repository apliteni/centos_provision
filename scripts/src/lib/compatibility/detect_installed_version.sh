#!/usr/bin/env bash

detect_installed_version(){
  if empty "${INSTALLED_VERSION}"; then
    detect_inventory_path
    if isset "${DETECTED_INVENTORY_PATH}"; then
      INSTALLED_VERSION=$(grep "^installer_version=" ${DETECTED_INVENTORY_PATH} | sed s/^installer_version=//g)
      debug "Got installer_version='${INSTALLED_VERSION}' from ${DETECTED_INVENTORY_PATH}"
    fi
    if empty "$INSTALLED_VERSION"; then
      debug "Couldn't detect installer_version, resetting to 0.9"
      INSTALLED_VERSION="0.9"
    fi
  fi
}
