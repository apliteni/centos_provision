#!/usr/bin/env bash
#




validate_keitaro_dump(){
  local file="${1}"
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local mime_type="$(detect_mime_type ${file})"
  debug "Detected mime type: ${mime_type}"
  local get_head_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "head" "100")"
  if [[ "$get_head_chunk" == "" ]]; then
    return ${FAILURE_RESULT}
  fi
  detect_tables_prefix "$get_head_chunk"
  if [[ "$TABLES_PREFIX" == "" ]]; then
    return ${FAILURE_RESULT}
  fi
  if [[ "schema_version" -lt "${TABLES_PREFIX}acl" ]]; then
    ensure_table_dumped "$get_head_chunk" "schema_version"
  else
    local get_tail_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "tail" "50")"
    ensure_table_dumped "$get_tail_chunk" "schema_version"
  fi
}

ensure_table_dumped(){
  local get_table_chunk="${1}"
  local table="${2}"
  command="${get_table_chunk} | grep -qP $(build_check_table_exists_expression "$table")"
  message="$(translate 'messages.check_keitaro_dump_validity')"
  run_command "${command}" "${message}" 'hide_output' 'allow_errors' > /dev/stderr
}


detect_tables_prefix(){
  local get_head_chunk="${1}"
  local command=$get_head_chunk
  command="${command} | grep -P $(build_check_table_exists_expression ".*acl")"
  command="${command} | head -n 1"
  command="${command} | grep -oP '\`.*\`'"
  command="${command} | sed -e 's/\`//g' -e 's/acl\$//'"
  message="$(translate 'messages.check_keitaro_dump_get_tables_prefix')"
  if run_command "$command" "$message" 'hide_output' 'allow_errors' '' '' "$DETECTED_PREFIX_PATH" > /dev/stderr; then
    TABLES_PREFIX="$(cat "$DETECTED_PREFIX_PATH")"
    debug "Detected tables prefix: ${TABLES_PREFIX}"
    rm -f "$DETECTED_PREFIX_PATH"
  fi
}


build_check_table_exists_expression(){
  local table="${1}"
  echo "'^CREATE TABLE( IF NOT EXISTS)? \`${table}\`'"
}


build_get_chunk_command(){
  local mime_type="${1}"
  local file="${2}"
  local head_or_tail="${3}"
  local chunk_size="${4}"
  if [[ "$mime_type" == 'text/plain' ]]; then
    echo "${head_or_tail} -n ${chunk_size} '${file}'"
  fi
  if [[ "$mime_type" == 'application/x-gzip' ]]; then
    echo "zcat '${file}' | ${head_or_tail} -n ${chunk_size}"
  fi
}


eval_bash(){
  local command="${1}"
  debug "Evaluating command \`${command}\`"
  bash -c "${command}"
}
