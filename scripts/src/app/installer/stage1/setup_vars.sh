#!/usr/bin/env bash
#





setup_vars(){
  setup_default_value skip_firewall no
  setup_default_value admin_login 'admin'
  setup_default_value admin_password "$(generate_password)"
  setup_default_value db_name 'keitaro'
  setup_default_value db_user 'keitaro'
  setup_default_value db_password "$(generate_password)"
  setup_default_value db_root_password "$(generate_password)"
  setup_default_value db_engine 'tokudb'
  setup_default_value php_engine "${PHP_ENGINE}"
  setup_default_value ssh_port "$(get_firewall_ssh_port)"
}

get_firewall_ssh_port(){
  local sshport=`echo $SSH_CLIENT | cut -d' ' -f 3`
  if [ -z "$sshport" ]; then
    echo "22"
  else
    if [ "$sshport" != "22" ]; then
      echo "$sshport"
    else
      echo "22"
    fi
  fi
}

setup_default_value(){
  local var_name="${1}"
  local default_value="${2}"
  if empty "${VARS[${var_name}]}"; then
    debug "VARS['${var_name}'] is empty, set to '${default_value}'"
    VARS[${var_name}]=$default_value
  else
    debug "VARS['${var_name}'] is set to '${VARS[$var_name]}'"
  fi
}


generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}
