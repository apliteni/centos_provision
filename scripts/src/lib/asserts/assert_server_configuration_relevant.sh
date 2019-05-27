#!/usr/bin/env bash
#






assert_server_configuration_relevant(){
  debug 'Ensure configs has been genereated by relevant installer'
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of installer version in ${INVENTORY_FILE} disabled"
  else
    installed_version=$(detect_installed_version)
    if [[ "${RELEASE_VERSION}" == "${installed_version}" ]]; then
      debug "Configs has been generated by recent version of installer ${RELEASE_VERSION}"
    else
      local tool_url="${KEITARO_URL}/release-${installed_version}/${TOOL_NAME}.sh"
      local tool_args="${TOOL_ARGS}"
      if [[ "${TOOL_NAME}" == "add-site" ]]; then
        if [[ "${installed_version}" < "1.4" ]]; then
          fail "$(build_upgrade_message($installed_version))"
        else
          tool_args="-D ${VARS['site_domains']} -R ${VARS['site_root']}"
        fi
      fi
      if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
        if [[ "${installed_version}" < "1.4" ]]; then
          tool_args="-wa ${VARS['ssl_domains']//,/ }"
        else
          tool_args="-D ${VARS['ssl_domains']}"
        fi
      fi
      command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
      run_command "${command}" "Run obsolete ${TOOL_NAME} (v${installed_version})"
      exit
    fi
  fi
}


detect_installed_version(){
  local version=""
  if is_file_exist ${INVENTORY_FILE}; then
    version=$(grep "^installer_version=" ${INVENTORY_FILE} | sed s/^installer_version=//g)
  fi
  if empty "$version"; then
    version="0.9"
  fi
  echo "$version"
}


build_upgrade_message(){
  local installed_version="${1}"
  translate 'errors.upgrade_server' "installed_version=${installed_version}"
}
