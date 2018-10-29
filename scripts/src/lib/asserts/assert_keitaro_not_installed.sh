#!/usr/bin/env bash
#





assert_keitaro_not_installed(){
  debug 'Ensure keitaro is not installed yet'
  if isset "$RECONFIGURE"; then
    debug 'Skip checking install.lock'
    return
  fi
  if is_exists_file /var/www/keitaro/var/install.lock no; then
    debug 'NOK: keitaro is already installed'
    fail "$(translate errors.keitaro_already_installed)"
  else
    debug 'OK: keitaro is not installed yet'
  fi
}