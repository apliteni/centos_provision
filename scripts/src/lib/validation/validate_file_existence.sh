#!/usr/bin/env bash
#





validate_file_existence(){
  local value="${1}"
  if empty "$value"; then
    return ${SUCCESS_RESULT}
  fi
  [[ -f "$value" ]]
}
