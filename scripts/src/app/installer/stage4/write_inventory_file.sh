#!/usr/bin/env bash


write_inventory_file(){
  debug "Writing inventory file: STARTED"
  mkdir -p "${INVENTORY_DIR}" -m 0700 || fail "Cant't create keitaro inventory dir ${INVENTORY_DIR}"
  (echo -n > "${INVENTORY_FILE}" && chmod 0600 "${INVENTORY_FILE}") || \
    fail "Cant't create keitaro inventory file ${INVENTORY_FILE}"
  print_line_to_inventory_file "[server]"
  print_line_to_inventory_file "localhost connection=local ansible_user=root"
  print_line_to_inventory_file
  print_line_to_inventory_file "[server:vars]"
  print_line_to_inventory_file "skip_firewall=${VARS['skip_firewall']}"
  print_line_to_inventory_file "license_ip="${VARS['license_ip']}""
  print_line_to_inventory_file "license_key="${VARS['license_key']}""
  print_line_to_inventory_file "db_root_password="${VARS['db_root_password']}""
  print_line_to_inventory_file "db_name="${VARS['db_name']}""
  print_line_to_inventory_file "db_user="${VARS['db_user']}""
  print_line_to_inventory_file "db_password="${VARS['db_password']}""
  print_line_to_inventory_file "db_restore_path="${VARS['db_restore_path']}""
  print_line_to_inventory_file "db_restore_salt="${VARS['db_restore_salt']}""
  print_line_to_inventory_file "admin_login="${VARS['admin_login']}""
  print_line_to_inventory_file "admin_password="${VARS['admin_password']}""
  print_line_to_inventory_file "language=$(get_ui_lang)"
  print_line_to_inventory_file "installer_version=${RELEASE_VERSION}"
  print_line_to_inventory_file "evaluated_by_installer=yes"
  print_line_to_inventory_file "cpu_cores=$(get_cpu_cores)"
  print_line_to_inventory_file "php_engine=${VARS['php_engine']}"
  if isset "${VARS['db_engine']}"; then
    print_line_to_inventory_file "db_engine=${VARS['db_engine']}"
  fi
  if isset "$KEITARO_RELEASE"; then
    print_line_to_inventory_file "kversion=$KEITARO_RELEASE"
  fi
  if isset "$CUSTOM_PACKAGE"; then
    print_line_to_inventory_file "custom_package=$CUSTOM_PACKAGE"
  fi
  debug "Writing inventory file: DONE"
}


get_cpu_cores(){
  cpu_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
  if [[ "$cpu_cores" == "0" ]]; then
    cpu_cores=1
  fi
  echo "$cpu_cores"
}

print_line_to_inventory_file(){
  local line="${1}"
  debug "  "$line"" 'light.blue'
  echo "$line" >> "$INVENTORY_FILE"
}
