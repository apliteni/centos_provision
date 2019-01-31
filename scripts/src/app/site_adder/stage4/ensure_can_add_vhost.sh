#!/usr/bin/env bash

ensure_can_add_vhost(){
  debug "Ensure can add vhost"
  if is_path_exist "$(vhost_filepath)" "no"; then
    fail "$(translate 'errors.vhost_already_exists' "vhost_filepath=$(vhost_filepath)")"
  fi
  if ! is_directory_exist "${VARS['site_root']}"; then
    fail "$(translate 'errors.site_root_not_exists' "site_root=${VARS['site_root']})"
  fi
}
