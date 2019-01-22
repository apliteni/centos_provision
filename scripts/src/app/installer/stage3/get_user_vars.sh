#!/usr/bin/env bash
#





get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  print_translated "welcome"
  if ! can_install_firewall; then
    get_user_var 'skip_firewall' 'validate_yes_no'
    if is_no "${VARS['skip_firewall']}"; then
      fail "$(translate 'errors.cant_install_firewall')"
    fi
  fi
  get_user_ssl_vars
  get_user_var 'db_restore' 'validate_presence validate_yes_no'
  if is_yes "${VARS['db_restore']}"; then
    get_user_var_db_restore_path
    get_user_var 'db_restore_salt' 'validate_presence validate_alnumdashdot'
  fi
  common_validators="validate_presence validate_alnumdashdot validate_not_reserved_word"
  get_user_var 'db_name' "${common_validators} validate_starts_with_latin_letter"
  get_user_var 'db_user' "${common_validators} validate_starts_with_latin_letter validate_not_root"
  get_user_var 'db_password' "${common_validators}"
  if is_no "${VARS['db_restore']}"; then
    get_user_var 'admin_login' "${common_validators} validate_starts_with_latin_letter"
    get_user_var 'admin_password' "${common_validators}"
  fi
  if empty "${VARS['license_ip']}"; then
    VARS['license_ip']=$(get_host_ip)
  fi
  get_user_var 'license_ip' 'validate_presence validate_ip'
  get_user_var 'license_key' 'validate_presence validate_license_key'
}


get_user_ssl_vars(){
  VARS['ssl_certificate']='self-signed'
  get_user_var 'ssl' 'validate_yes_no'
  if is_yes ${VARS['ssl']}; then
    VARS['ssl_certificate']='letsencrypt'
    get_user_var 'ssl_domains' 'validate_presence validate_domains_list'
    get_user_var 'ssl_email'
  fi
}


get_user_var_db_restore_path(){
  get_user_var 'db_restore_path' 'validate_presence validate_file_existence'
  if ! is_keitaro_dump_valid ${VARS['db_restore_path']}; then
    print_prompt_error 'validate_keitaro_dump'
    get_user_var 'db_restore_path_want_exit' 'validate_yes_no'
    if is_yes "${VARS['db_restore_path_want_exit']}"; then
      fail "$(translate 'errors.keitaro_dump_invalid')"
    else
      get_user_var_db_restore_path
    fi
  fi
}


is_keitaro_dump_valid(){
  local file="${1}"
  local cat_command=''
  local mime_type="$(detect_mime_type ${file})"
  debug "Detected mime type: ${mime_type}"
  if [[ "$mime_type" == 'application/x-gzip' ]]; then
    grep_command='zgrep'
  else
    grep_command='grep'
  fi
  check_table_1="$(ensure_table_dumped "${grep_command}" "keitaro_clicks" "${file}")"
  check_table_2="$(ensure_table_dumped "${grep_command}" "schema_version" "${file}")"
  ensure_tables_dumped="${check_table_1} && ${check_table_2}"
  message="$(translate 'messages.check_keitaro_dump_validity')"
  run_command "${ensure_tables_dumped}" "${message}" 'hide_output' 'allow_errors'
}

ensure_table_dumped(){
  local grep_command="${1}"
  local table="${2}"
  local file="${3}"
  echo "${grep_command} -qP '^CREATE TABLE( IF NOT EXISTS)? \`${table}\`' ${file}"
}

can_install_firewall(){
  command='iptables -t nat -L'
  message="$(translate 'messages.check_ability_firewall_installing')"
  run_command "$command" "$message" 'hide_output' 'allow_errors'
}
