#!/usr/bin/env bash

detect_license_ip(){
  debug "Detecting license ip"
  if isset "$SKIP_CHECKS"; then
    DETECTED_LICENSE_EDITION_TYPE=$LICENSE_EDITION_TYPE_TRIAL
    VARS['license_ip']="127.0.0.1"
    debug "SKIP: actual detecting of license IP skipped, used 127.0.0.1"
  else
    host_ips="$(get_host_ips)"
    debug "$(echo 'IPs for checking:' ${host_ips})"
    for ip in ${host_ips}; do
      local license_edition_type="$(get_license_edition_type "${VARS['license_key']}" "${ip}")"
      if wrong_license_edition_type $license_edition_type; then
        debug "Got wrong license edition type: ${license_edition_type}"
        fail "$(translate 'errors.cant_detect_server_ip')" "see_logs"
      fi
      if [[ "${license_edition_type}" == "${LICENSE_EDITION_TYPE_INVALID}" ]]; then
        debug "Valid license for IP ${ip} and key ${VARS['license_key']} not found"
      else
        debug "Found $license_edition_type license for IP ${ip} and key ${VARS['license_key']}"
        DETECTED_LICENSE_EDITION_TYPE="${license_edition_type}"
        VARS['license_ip']="$ip"
        debug "Detected license ip: ${VARS['license_ip']}"
        return
      fi
    done
    debug "No valid license found for key ${VARS['license_key']} and IPs $(get_host_ips)"
    fail "$(translate 'errors.cant_detect_server_ip')" "see_logs"
  fi
}

get_license_edition_type(){
  local key="${1}"
  local ip="${2}"
  debug "Detecting license edition type for ip ${ip}"
  local url="${KEITARO_URL}/external_api/licenses/edition_type?key=${key}&ip=${ip}"
  debug "Getting url '${url}'"
  local result="$(curl -fsSL "${url}" 2>&1)"
  debug "Done, result is '$result'"
  echo $result
}

wrong_license_edition_type(){
  local license_edition_type="${1}"
  [[ ! $license_edition_type =~ ^($(join_by "|" "${LICENSE_EDITION_TYPES[@]}"))$ ]]
}
