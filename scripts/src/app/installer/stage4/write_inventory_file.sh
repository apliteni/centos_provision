#!/usr/bin/env bash
#





write_inventory_file(){
  debug "Write inventory file"
  echo -n > "$INVENTORY_FILE"
  print_line_to_inventory_file "[server]"
  print_line_to_inventory_file "localhost connection=local ansible_user=root"
  print_line_to_inventory_file
  print_line_to_inventory_file "[server:vars]"
  print_line_to_inventory_file "skip_firewall=${VARS['skip_firewall']}"
  print_line_to_inventory_file "ssl="${VARS['ssl']}""
  print_line_to_inventory_file "ssl_domains="${VARS['ssl_domains']}""
  print_line_to_inventory_file "ssl_email="${VARS['ssl_email']}""
  print_line_to_inventory_file "license_ip="${VARS['license_ip']}""
  print_line_to_inventory_file "license_key="${VARS['license_key']}""
  print_line_to_inventory_file "db_name="${VARS['db_name']}""
  print_line_to_inventory_file "db_user="${VARS['db_user']}""
  print_line_to_inventory_file "db_password="${VARS['db_password']}""
  print_line_to_inventory_file "db_restore="${VARS['db_restore']}""
  print_line_to_inventory_file "db_restore_path="${VARS['db_restore_path']}""
  print_line_to_inventory_file "db_restore_salt="${VARS['db_restore_salt']}""
  print_line_to_inventory_file "admin_login="${VARS['admin_login']}""
  print_line_to_inventory_file "admin_password="${VARS['admin_password']}""
  print_line_to_inventory_file "language=${UI_LANG}"
  print_line_to_inventory_file "installer_version=${SCRIPT_VERSION}"
  print_line_to_inventory_file "evaluated_by_installer=yes"
  print_line_to_inventory_file "cpu_cores=$(get_cpu_cores)"
  if isset "$KEITARO_RELEASE"; then
    print_line_to_inventory_file "kversion=$KEITARO_RELEASE"
  fi
  if isset "$CUSTOM_PACKAGE"; then
    print_line_to_inventory_file "custom_package=$CUSTOM_PACKAGE"
  fi
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
