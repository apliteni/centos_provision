#!/usr/bin/env bash

validate_not_root(){
  local value="${1}"
  [[ "$value" !=  'root' ]]
}
