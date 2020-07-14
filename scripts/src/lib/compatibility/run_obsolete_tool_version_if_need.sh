#!/usr/bin/env bash


run_obsolete_tool_version_if_need(){
  debug 'Ensure configs has been genereated by relevant installer'
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of installer version in ${INVENTORY_PATH} disabled"
  else
    local installed_version=$(detect_installed_version)
    local current_major_release=${RELEASE_VERSION/\.*/}
    local installed_major_release=${installed_version/\.*/}
    if [[ "${installed_major_release}" == "${current_major_release}" ]]; then
      debug "Current ${RELEASE_VERSION} is compatible with ${installed_version}"
    else
      local tool_url="${KEITARO_URL}/v${installed_version}/${TOOL_NAME}.sh"
      local tool_args="${TOOL_ARGS}"
      if [[ "${TOOL_NAME}" == "add-site" ]]; then
        if (( $(as_version "${installed_version}") < $(as_version "1.4") )); then
          fail "$(translate 'errors.upgrade_server')"
        else
          tool_args="-D ${VARS['site_domains']} -R ${VARS['site_root']}"
        fi
      fi
      if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
        if (( $(as_version "${installed_version}") < $(as_version "1.4") )); then
          tool_args="-wa ${VARS['ssl_domains']//,/ }"
        else
          tool_args="-D ${VARS['ssl_domains']}"
        fi
      fi
      command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
      run_command "${command}" "Running obsolete ${TOOL_NAME} (v${installed_version})"
      exit
    fi
  fi
}
