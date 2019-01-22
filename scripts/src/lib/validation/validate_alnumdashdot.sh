#!/usr/bin/env bash

validate_alnumdashdot(){
  local value="${1}"
  [[ "$value" =~  ^([0-9A-Za-z_\.\-]+)$ ]]
}
