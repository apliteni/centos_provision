#!/usr/bin/env bash
#





validate_keitaro_dump(){
  local file="${1}"
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local cat_command=''
  local mime_type="$(detect_mime_type ${file})"
  debug "Detected mime type: ${mime_type}"
  if [[ "$mime_type" == 'application/x-gzip' ]]; then
    grep_command='zgrep'
    check_table_2="$(ensure_table_dumped "${grep_command}" "schema_version") ${file}"
  else
    if [[ "$mime_type" == 'text/plain' ]]; then
      grep_command='grep'
      check_table_2="tail -n 100 ${file} | $(ensure_table_dumped "${grep_command}" "schema_version")"
    else
      return ${FAILURE_RESULT}
    fi
  fi
  check_table_1="$(ensure_table_dumped "${grep_command}" "keitaro_acl") ${file}"
  ensure_tables_dumped="${check_table_1} && ${check_table_2}"
  message="$(translate 'messages.check_keitaro_dump_validity')"
  run_command "${ensure_tables_dumped}" "${message}" 'hide_output' 'allow_errors' > /dev/stderr
}


ensure_table_dumped(){
  local grep_command="${1}"
  local table="${2}"
  echo "${grep_command} -qP $(build_check_table_exists_expression "$table")"
}


build_check_table_exists_expression(){
  local table="${1}"
  echo "'^CREATE TABLE( IF NOT EXISTS)? \`${table}\`'"
}
