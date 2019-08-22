#!/usr/bin/env bash


write_inventory_on_reconfiguration(){
  debug "Stages 3-5: write inventory on reconfiguration"
  if empty "${DETECTED_INVENTORY_PATH}"; then
    debug "Detecting inventory variables"
    reset_vars_on_reconfiguration
    detect_inventory_variables
  fi
  if empty "${VARS['license_ip']}"; then
    fail "Cant't detect license ip, please contact Keitaro support team"
  fi
  if empty "${VARS['license_key']}"; then
    fail "Cant't detect license ip, please contact Keitaro support team"
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


detect_inventory_variables(){
  if empty "${VARS['license_key']}"; then
    if [[ -f ${WEBROOT_PATH}/var/license/key.lic ]]; then
      VARS['license_key']="$(cat ${WEBROOT_PATH}/var/license/key.lic)"
      debug "Detected license key: ${VARS['license_key']}"
    fi
  fi
  if empty "${VARS['license_ip']}"; then
    VARS['license_ip']="$(detect_license_ip)"
    debug "Detected license ip: ${VARS['license_ip']}"
  fi
  if empty "${VARS['db_name']}"; then
    VARS['db_name']="$(get_var_from_keitaro_app_config name)"
    debug "Detected db name: ${VARS['db_name']}"
  fi
  if empty "${VARS['db_user']}"; then
    VARS['db_user']="$(get_var_from_keitaro_app_config user)"
    debug "Detected db user: ${VARS['db_user']}"
  fi
  if empty "${VARS['db_password']}"; then
    VARS['db_password']="$(get_var_from_keitaro_app_config password)"
    debug "Detected db password: ${VARS['db_password']}"
  fi
  if empty "${VARS['db_root_password']}"; then
    VARS['db_root_password']="$(get_var_from_config password ~/.my.cnf '=')"
    debug "Detected db root password: ${VARS['db_root_password']}"
  fi
}


get_var_from_keitaro_app_config(){
  local var="${1}"
  get_var_from_config "${var}" "${WEBROOT_PATH}/application/config/config.ini.php" '='
}
