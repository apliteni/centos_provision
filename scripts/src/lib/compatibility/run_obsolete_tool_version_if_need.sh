#!/usr/bin/env bash

run_obsolete_tool_version_if_need() {
  debug 'Ensure configs has been genereated by relevant installer'
  if is_compatible_with_current_release; then
    debug "Current ${RELEASE_VERSION} is compatible with ${INSTALLED_VERSION}"
  else
    local tool_url="${KEITARO_URL}/v${INSTALLED_VERSION}/${TOOL_NAME}.sh"
    local tool_args="${TOOL_ARGS}"
    if (( $(as_version "${INSTALLED_VERSION}") < $(as_version "1.13") )); then
      fail "$(translate 'errors.upgrade_server')"
    fi
    if [[ "${TOOL_NAME}" == "add-site" ]]; then
      tool_args="-D ${VARS['site_domains']} -R ${VARS['site_root']}"
    fi
    if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
      tool_args="-D ${VARS['ssl_domains']}"
    fi
    command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
    run_command "${command}" "Running obsolete ${TOOL_NAME} (v${INSTALLED_VERSION})"
    exit
  fi
}
