#!/usr/bin/env bash
#





assert_nginx_configured(){
  if ! is_nginx_properly_configured; then
    fail "$(translate 'errors.reinstall_keitaro_ssl')" "see_logs"
  fi
}


is_nginx_properly_configured(){
  if ! is_file_exist "${NGINX_KEITARO_CONF}"; then
    log_and_print_err "ERROR: File ${NGINX_KEITARO_CONF} doesn't exists"
    return ${FAILURE_RESULT}
  fi
  if ! is_file_exist "${NGINX_SSL_CERT_PATH}"; then
    log_and_print_err "ERROR: File ${NGINX_SSL_CERT_PATH} doesn't exists"
    return ${FAILURE_RESULT}
  fi
  if ! is_file_exist "${NGINX_SSL_PRIVKEY_PATH}"; then
    log_and_print_err "ERROR: File ${NGINX_SSL_PRIVKEY_PATH} doesn't exists"
    return ${FAILURE_RESULT}
  fi
  is_ssl_configured
}


is_ssl_configured(){
  debug "Checking ssl params in ${NGINX_KEITARO_CONF}"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ssl params in ${NGINX_KEITARO_CONF} disabled"
    return ${SUCCESS_RESULT}
  fi
  if grep -q -e "ssl_certificate #{NGINX_SSL_CERT_PATH};" -e "ssl_certificate_key ${NGINX_SSL_PRIVKEY_PATH};" "${NGINX_KEITARO_CONF}"; then
    debug "OK: it seems like ${NGINX_KEITARO_CONF} is properly configured"
    return ${SUCCESS_RESULT}
  else
    log_and_print_err "ERROR: ${NGINX_KEITARO_CONF} is not properly configured"
    log_and_print_err $(print_content_of "$NGINX_KEITARO_CONF")
    return ${FAILURE_RESULT}
  fi
}
