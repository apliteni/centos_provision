#!/usr/bin/env bash
#





write_inventory_on_reconfiguration(){
  if ! is_file_exist ${INVENTORY_FILE}; then
    collect_inventory_variables
    write_inventory_file
  fi
}


collect_inventory_variables(){
  if is_file_exist "${HOME}/hosts.txt"; then
    read_inventory_file "${HOME}/hosts.txt"
  fi
  if empty VARS['license_key']; then
    VARS['license_key']="$(cat ${WEBROOT_PATH}/var/license/key.lic)"
    VARS['license_ip']="$(get_host_ip)"
    VARS['db_name']="$(get_var_from_keitaro_config name)"
    VARS['db_user']="$(get_var_from_keitaro_config user)"
    VARS['db_password']="$(get_var_from_keitaro_config password)"
    VARS['db_root_password']="$(get_var_from_config ~/.my.cnf password '=')"
    VARS['admin_login']=''
    VARS['admin_password']=''
  fi
}


get_var_from_keitaro_config(){
  local var="${1}"
  get_var_from_config "${var}" "${WEBROOT_PATH}/application/config/config.ini.php" '='
}
