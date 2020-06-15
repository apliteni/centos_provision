#!/usr/bin/env bash

USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE="2.12"
KEITARO_LOCK_FILEPATH="${WEBAPP_ROOT}/var/install.lock"

assert_keitaro_not_installed(){
  debug 'Ensure keitaro is not installed yet'
  if is_keitaro_installed; then
    debug 'NOK: keitaro is already installed'
    print_err "$(translate messages.keitaro_already_installed)" 'yellow'
    show_credentials
    clean_up
    exit ${KEITARO_ALREADY_INSTALLED_RESULT}
  else
    debug 'OK: keitaro is not installed yet'
  fi
}

is_keitaro_installed() {
   if should_use_new_algorithm_for_installation_check; then
     debug "Current version is ${RELEASE_VERSION} - using new algorithm (check 'installed' flag in the inventory file)"
     isset "${VARS['installed']}"
   else
     debug "Current version is ${RELEASE_VERSION} - using old algorithm (check '${KEITARO_LOCK_FILEPATH}' file)"
     is_file_exist "${KEITARO_LOCK_FILEPATH}" no
   fi
}

should_use_new_algorithm_for_installation_check() {
 [[ ! $(version_to_number ${RELEASE_VERSION}) < $(version_to_number ${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE}) ]]
}
