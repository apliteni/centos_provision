#!/usr/bin/env bash
#





is_path_exist(){
  local path="${1}"
  local result_on_skip="${2}"
  debug "Checking ${path} path existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ${path} path existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${path} path does not exist"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${path} path exists"
    return ${SUCCESS_RESULT}
  fi
  if [ -e "${path}" ]; then
    debug "YES: ${path} path exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${path} path does not exist"
    return ${FAILURE_RESULT}
  fi
}
