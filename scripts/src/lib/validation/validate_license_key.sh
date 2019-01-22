#!/usr/bin/env bash

validate_license_key(){
  local value="${1}"
  [[ "$value" =~  ^[0-9A-Z]{4}(-[0-9A-Z]{4}){3}$ ]]
}
