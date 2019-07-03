#!/usr/bin/env bash
#


FIRST_KEITARO_TABLE_NAME="acl"

validate_keitaro_dump(){
  local file="${1}"
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local mime_type="$(detect_mime_type "${file}")"
  debug "Detected mime type: ${mime_type}"
  local get_head_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "head" "100")"
  if empty "${get_head_chunk}"; then
    return ${FAILURE_RESULT}
  fi
  local tables_prefix="$(detect_tables_prefix "${get_head_chunk}")"
  if empty "${tables_prefix}"; then
    return ${FAILURE_RESULT}
  else
    debug "Detected tables prefix: ${tables_prefix}"
  fi
  if [[ "schema_version" < "${tables_prefix}${FIRST_KEITARO_TABLE_NAME}" ]]; then
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
  command="${command} | grep -P $(build_check_table_exists_expression ".*${FIRST_KEITARO_TABLE_NAME}")"
  command="${command} | head -n 1"
  command="${command} | grep -oP '\`.*\`'"
  command="${command} | sed -e 's/\`//g' -e 's/${FIRST_KEITARO_TABLE_NAME}\$//'"
  message="$(translate 'messages.check_keitaro_dump_get_tables_prefix')"
  rm -f "${DETECTED_PREFIX_PATH}"
  if run_command "$command" "$message" 'hide_output' 'allow_errors' '' '' "$DETECTED_PREFIX_PATH" > /dev/stderr; then
    cat "$DETECTED_PREFIX_PATH" | head -n1
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
    echo "(zcat '${file}'; true) | ${head_or_tail} -n ${chunk_size}"
  fi
}


eval_bash(){
  local command="${1}"
  debug "Evaluating command \`${command}\`"
  bash -c "${command}"
}
