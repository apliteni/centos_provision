#!/usr/bin/env bash
#





is_file_matches(){
  local file="${1}"
  local pattern="${2}"
  local result_on_skip="${3}"
  debug "Checking ${file} file matching with pattern '${pattern}'"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of ${file} file matching disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${file} file does not match '${pattern}'"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  fi
  if test -f "$file" && grep -q "$pattern" "$file"; then
    debug "YES: ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not match '${pattern}"
    return ${FAILURE_RESULT}
  fi
}
