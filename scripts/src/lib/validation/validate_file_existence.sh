#!/usr/bin/env bash

validate_file_existence(){
  local value="${1}"
  [[ -f "$value" ]]
}
