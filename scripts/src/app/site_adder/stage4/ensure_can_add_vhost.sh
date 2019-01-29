#!/usr/bin/env bash

ensure_can_add_vhost(){
  debug "Ensure can add vhost"
  if is_exists_path "$(vhost_filepath)" "no"; then
    local message="$(translate 'errors.vhost_already_exists')"
    fail "${message/:vhost_filepath:/$(vhost_filepath)}"
  fi
  if ! is_directory_exist "${VARS['site_root']}"; then
    local message="$(translate 'errors.site_root_not_exists')"
    fail "${message/:site_root:/${VARS['site_root']}}"
  fi
}
