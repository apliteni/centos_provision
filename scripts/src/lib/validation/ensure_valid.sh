#!/usr/bin/env bash
#





ensure_valid(){
  local var_name="${1}"
  local validation_methods="${2}"
  if isset "$(get_error "${var_name}" "$validation_methods")"; then
    wrong_options
  fi
}
