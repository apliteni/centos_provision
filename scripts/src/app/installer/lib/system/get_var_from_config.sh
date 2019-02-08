#!/usr/bin/env bash

get_var_from_config(){
  local var="${1}"
  local file="${2}"
  local separator="${3}"
  cat "$file" | \
    grep "^${var}\\b" | \
    grep "${separator}" | \
    head -n1 | \
    awk -F"${separator}" '{print $2}' | \
    awk '{$1=$1; print}' | \
    sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
  }
