#!/usr/bin/env bash
#






assert_nginx_configured(){
  if ! is_nginx_properly_configured; then
    fail "$(translate 'errors.reinstall_keitaro')" "see_logs"
  fi
}


is_nginx_properly_configured(){
  if ! is_file_exist "${NGINX_KEITARO_CONF}"; then
    log_and_print_err "ERROR: File ${NGINX_KEITARO_CONF} doesn't exists"
    return ${FAILURE_RESULT}
  fi
  if ! is_exists_directory "${WEBROOT_PATH}"; then
    log_and_print_err "ERROR: Directory ${WEBROOT_PATH} doesn't exists"
    return ${FAILURE_RESULT}
  fi
  is_keitaro_configured
}


is_keitaro_configured(){
  debug "Checking keitaro params in ${NGINX_KEITARO_CONF}"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of keitaro params in ${NGINX_KEITARO_CONF} disabled"
    FASTCGI_PASS_LINE="fastcgi_pass unix:/var/run/php70-fpm.sock;"
    return ${SUCCESS_RESULT}
  fi
  if grep -q -e "root ${WEBROOT_PATH};" "${NGINX_KEITARO_CONF}"; then
    FASTCGI_PASS_LINE="$(cat "$NGINX_KEITARO_CONF" | grep fastcgi_pass | sed 's/^ +//' | head -n1)"
    if empty "${FASTCGI_PASS_LINE}"; then
      log_and_print_err "ERROR: ${NGINX_KEITARO_CONF} is not properly configured (can't find 'fastcgi_pass ...;' directive)"
      log_and_print_err "$(print_content_of ${NGINX_KEITARO_CONF})"
      return ${FAILURE_RESULT}
    else
      debug "OK: it seems like ${NGINX_KEITARO_CONF} is properly configured"
      return ${SUCCESS_RESULT}
    fi
  else
    log_and_print_err "ERROR: ${NGINX_KEITARO_CONF} is not properly configured (can't find 'root ${WEBROOT_PATH};' directive"
    log_and_print_err $(print_content_of ${NGINX_KEITARO_CONF})
    return ${FAILURE_RESULT}
  fi
}
