#!/usr/bin/env bash

ensure_variables_are_set() {
  while [[ "${1}" != "" ]]; do
    local variable_name="${1}"
    local variable_value="${!variable_name}"
    if [[ -z "${variable_value}" ]]; then
      echo "${variable_name} is empty"
      exit 1
    fi
    shift
  done
}

