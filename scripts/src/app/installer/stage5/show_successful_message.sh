#!/usr/bin/env bash
#





show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
  if isset "$ANSIBLE_TAGS"; then
    debug 'ansible tags is set to ${ANSIBLE_TAGS} - skip printing credentials'
    return
  fi
  if [[ "${VARS['ssl_certificate']}" == 'letsencrypt' ]] && isset "${SSL_SUCCESSFUL_DOMAINS}" ]]; then
    protocol='https'
    domain=$(expr match "${SSL_SUCCESSFUL_DOMAINS}" '\([^ ]*\)')
  else
    protocol='http'
    domain="${VARS['license_ip']}"
  fi
  print_with_color "${protocol}://${domain}/admin" 'light.green'
  if is_yes "${VARS['db_restore']}"; then
    echo "$(translate 'messages.successful.use_old_credentials')"
  else
    colored_login=$(print_with_color "${VARS['admin_login']}" 'light.green')
    colored_password=$(print_with_color "${VARS['admin_password']}" 'light.green')
    echo -e "login: ${colored_login}"
    echo -e "password: ${colored_password}"
  fi
  if isset "$SSL_FAILED_MESSAGE"; then
    print_with_color "${SSL_FAILED_MESSAGE}" 'yellow'
    print_with_color "$(cat "$SSL_ENABLER_ERRORS_LOG")" 'yellow'
    print_with_color "$(translate messages.successful.rerun_ssl_enabler)" 'yellow'
    print_with_color "${SSL_RERUN_COMMAND}" 'yellow'
  fi
}
