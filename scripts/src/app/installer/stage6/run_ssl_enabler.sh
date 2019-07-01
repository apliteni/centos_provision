#!/usr/bin/env bash
#




SSL_SUCCESSFUL_DOMAINS=""
SSL_FAILED_MESSAGE=""
SSL_RERUN_COMMAND=""
SSL_OUTPUT_LOG="${CONFIG_DIR}/enable-ssl.output.log"
SSL_SCRIPT_URL="${KEITARO_URL}/enable-ssl.sh"

run_ssl_enabler(){
  if isset "$ANSIBLE_TAGS"; then
    debug 'ansible tags is set to ${ANSIBLE_TAGS} - skip issuing LE certs'
    return
  fi
  if [[ "${VARS['ssl_certificate']}" == 'letsencrypt' ]]; then
    local command="curl -fsSL ${SSL_SCRIPT_URL} | bash -s -- -L $(get_ui_lang) -D ${VARS['ssl_domains']}"
    local message="$(translate 'messages.enabling_ssl')"
    > ${SSL_OUTPUT_LOG}
    run_command "${command}" "${message}" "hide_output" "" "" "" "${SSL_OUTPUT_LOG}"
    SSL_SUCCESSFUL_DOMAINS="$(extract_domains_from_enable_ssl_log ^OK)"
    local failed_domains="$(extract_domains_from_enable_ssl_log ^NOK)"
    SSL_FAILED_MESSAGE="$(get_message_from_enable_ssl_log ^NOK)"
    SSL_FAILED_MESSAGE="${SSL_FAILED_MESSAGE/NOK. /}"
    SSL_RERUN_COMMAND="curl -fsSL ${SSL_SCRIPT_URL} | bash -s -- -L $(get_ui_lang) -D ${failed_domains}"
    rm -f "${SSL_OUTPUT_LOG}"
  fi
}


remove_ansi_colors(){
  sed -r "s/\x1B\[(([0-9]+)(;[0-9]+)*)?[m,K,H,f,J]//g"
}


get_message_from_enable_ssl_log(){
  local prefix="${1}"
  if is_file_exist "${SSL_OUTPUT_LOG}" "no"; then
    cat "${SSL_OUTPUT_LOG}" \
      | remove_ansi_colors \
      | grep -E "${prefix}" || :
    fi
  }


extract_domains_from_enable_ssl_log(){
  local prefix="${1}"
  get_message_from_enable_ssl_log "$prefix" \
    | sed -e 's/.*: //g' -e 's/ //'     # extract domains list from message
  }
