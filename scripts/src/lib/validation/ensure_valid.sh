#!/usr/bin/env bash
#





ensure_valid(){
  local var_name="${1}"
  local validation_methods_string="${2}"
  error=$(get_error "${var_name}" "$validation_methods")
  if isset "$error"; then
    debug "$var_name: validation error - '${error}'"
    fail "$error"
  fi
}
