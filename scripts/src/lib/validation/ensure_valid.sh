#!/usr/bin/env bash
#





ensure_valid(){
  local option="${1}"
  local var_name="${2}"
  local validation_methods="${3}"
  error="$(get_error "${var_name}" "${validation_methods}")"
  if isset "$error"; then
    print_err "-${option}: $(translate "prompt_errors.${error}" "value=${VARS[$var_name]}")"
    exit ${FAILURE_RESULT}
  fi
}
