#!/usr/bin/env bash
#





is_file_exist(){
  local file="${1}"
  local result_on_skip="${2}"
  debug "Checking ${file} file existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ${file} file existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${file} file does not exist"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${file} file exists"
    return ${SUCCESS_RESULT}
  fi
  if [ -f "${file}" ]; then
    debug "YES: ${file} file exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not exist"
    return ${FAILURE_RESULT}
  fi
}
