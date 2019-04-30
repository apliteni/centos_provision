#!/usr/bin/env bash

validate_directory_existence(){
  local value="${1}"
  [[ -d "$value" ]]
}
