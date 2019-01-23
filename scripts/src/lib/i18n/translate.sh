#!/usr/bin/env bash
#





translate(){
  local key="${1}"
  local i18n_key=$UI_LANG.$key
  message="${DICT[$i18n_key]}"
  while isset "${2}"; do
    message=$(interpolate "${message}" "${2}")
    shift
  done
  echo "$message"
}


interpolate(){
  local string="${1}"
  local substitution="${2}"
  IFS="=" read name value <<< "${substitution}"
  string="${string//\{\{ ${name} \}\}/${value}}"
  echo "${string}"
}
