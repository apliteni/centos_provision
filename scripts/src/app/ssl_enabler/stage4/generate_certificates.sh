#!/usr/bin/env bash
#





generate_certificates(){
  debug "Requesting certificates"
  echo -n > "$SSL_ENABLER_ERRORS_LOG"
  for domain in "${DOMAINS[@]}"; do
    certificate_generated=${FALSE}
    certificate_error=""
    if certificate_exists_for_domain "$domain"; then
      SUCCESSFUL_DOMAINS+=($domain)
      debug "Certificate already exists for domain ${domain}"
      print_with_color "${domain}: $(translate 'warnings.certificate_exists_for_domain')" "yellow"
      certificate_generated=${TRUE}
    else
      debug "Certificate for domain ${domain} does not exist"
      if request_certificate_for "${domain}"; then
        SUCCESSFUL_DOMAINS+=($domain)
        debug "Certificate for domain ${domain} successfully issued"
        certificate_generated=${TRUE}
        rm -rf "$CERTBOT_LOG"
      else
        FAILED_DOMAINS+=($domain)
        debug "There was an error while issuing certificate for domain ${domain}"
        certificate_error="$(recognize_error "$CERTBOT_LOG")"
        echo "${domain}: ${certificate_error}" >> "$SSL_ENABLER_ERRORS_LOG"
      fi
    fi
    if [[ ${certificate_generated} == ${TRUE} ]]; then
      debug "Generating nginx config for ${domain}"
      setup_le_certs_in_vhost_config "${domain}"
    else
      debug "Skip generation nginx config ${domain} due errors while cert issuing"
      print_with_color "${domain}: ${certificate_error}" "red"
      print_with_color "${domain}: $(translate 'warnings.skip_nginx_config_generation')" "yellow"
    fi
  done
  rm -f "${CERT_DOMAINS_PATH}"
}


certificate_exists_for_domain(){
  local domain="${1}"
  is_directory_exist "/etc/letsencrypt/live/${domain}" "no"
}


request_certificate_for(){
  local domain="${1}"
  debug "Requesting certificate for domain ${domain}"
  certbot_command="certbot certonly --webroot --webroot-path=${WEBROOT_PATH}"
  certbot_command="${certbot_command} --agree-tos --non-interactive"
  certbot_command="${certbot_command} --domain ${domain}"
  if isset "${VARS['ssl_email']}"; then
    certbot_command="${certbot_command} --email ${VARS['ssl_email']}"
  else
    certbot_command="${certbot_command} --register-unsafely-without-email"
  fi
  requesting_message="$(translate "messages.requesting_certificate_for") ${domain}"
  run_command "${certbot_command}" "${requesting_message}" "hide_output" "allow_errors" "" "" "$CERTBOT_LOG"
}
