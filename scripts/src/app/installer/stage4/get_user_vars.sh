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
  get_user_license_vars
  get_user_ssl_vars
  get_user_db_restore_vars
}


get_user_license_vars(){
  get_user_var 'license_key' 'validate_presence validate_license_key'
  if empty "${VARS['license_ip']}" || empty "$DETECTED_LICENSE_EDITION_TYPE"; then
    detect_license_ip
  fi
}


get_user_ssl_vars(){
  get_user_var 'ssl' 'validate_yes_no'
  if is_yes ${VARS['ssl']}; then
    VARS['ssl_certificate']='letsencrypt'
    get_user_var 'ssl_domains' 'validate_presence validate_domains_list'
  fi
}


get_user_db_restore_vars(){
  get_user_var 'db_restore_path' 'validate_file_existence validate_keitaro_dump'
  if isset "${VARS['db_restore_path']}"; then
    get_user_var 'db_restore_salt' 'validate_presence validate_alnumdashdot'
  fi
}


can_install_firewall(){
  command='iptables -t nat -L'
  message="$(translate 'messages.check_ability_firewall_installing')"
  run_command "$command" "$message" 'hide_output' 'allow_errors'
}
