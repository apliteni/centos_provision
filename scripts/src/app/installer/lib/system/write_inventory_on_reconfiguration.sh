#!/usr/bin/env bash
#






write_inventory_on_reconfiguration(){
  debug "Stages 3-5: write inventory on reconfiguration"
  if ! is_file_exist "${HOME}/${INVENTORY_FILE}" "no" && ! is_file_exist "${INVENTORY_FILE}" "no"; then
    reset_vars_on_reconfiguration
    collect_inventory_variables
  fi
  VARS['installer_version']="${RELEASE_VERSION}"
  VARS['php_engine']="${PHP_ENGINE}"
  write_inventory_file
}


reset_vars_on_reconfiguration(){
  VARS['admin_login']=''
  VARS['admin_password']=''
  VARS['db_name']=''
  VARS['db_user']=''
  VARS['db_password']=''
  VARS['db_root_password']=''
  VARS['db_engine']=''
}


collect_inventory_variables(){
  if is_file_exist "${HOME}/hosts.txt"; then
    read_inventory_file "${HOME}/hosts.txt"
  fi
  if empty "${VARS['license_key']}"; then
    if [[ -f ${WEBROOT_PATH}/var/license/key.lic ]]; then
      VARS['license_key']="$(cat ${WEBROOT_PATH}/var/license/key.lic)"
    fi
  fi
  if empty "${VARS['license_ip']}"; then
    VARS['license_ip']="$(get_host_ip)"
  fi
  if empty "${VARS['db_name']}"; then
    VARS['db_name']="$(get_var_from_keitaro_app_config name)"
  fi
  if empty "${VARS['db_user']}"; then
    VARS['db_user']="$(get_var_from_keitaro_app_config user)"
  fi
  if empty "${VARS['db_password']}"; then
    VARS['db_password']="$(get_var_from_keitaro_app_config password)"
  fi
  if empty "${VARS['db_root_password']}"; then
    VARS['db_root_password']="$(get_var_from_config password ~/.my.cnf '=')"
  fi
}


get_var_from_keitaro_app_config(){
  local var="${1}"
  get_var_from_config "${var}" "${WEBROOT_PATH}/application/config/config.ini.php" '='
}
