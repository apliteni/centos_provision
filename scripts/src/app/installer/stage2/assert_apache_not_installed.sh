#!/usr/bin/env bash
#





assert_apache_not_installed(){
  if isset "$SKIP_CHECKS"; then
    debug "SKIPPED: actual checking of httpd skipped"
  else
    if is_installed httpd; then
      fail "$(translate errors.apache_installed)"
    fi
  fi
}
