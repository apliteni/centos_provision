#!/usr/bin/env bash

regenerate_self_signed_cert(){
  if [ -L ${SSL_CERT_PATH} ]; then
    debug "${SSL_CERT_PATH} is link. Getting cert domains"
    local domains=$(get_domains_from_cert)
    local main_domain=$(awk '{print $1}' <<< "${domains}")
    debug "Current domains in ${SSL_CERT_PATH}: ${domains}. Main domain: ${main_domain}"
    save_cert_domains "${domains}"
    remove_letsencrypt_certificate "$main_domain"
    generate_self_signed_certificate
  else
    debug "${SSL_CERT_PATH} is not link, do not regenerate self-signed cert"
  fi
}


get_domains_from_cert(){
  debug "Getting domains from existent cert"
  openssl x509 -text < "$SSL_CERT_PATH" | grep DNS | sed -r -e 's/(DNS:|,)//g'
}


save_cert_domains(){
  local domains="${1}"
  debug "Saving cert domains"
  echo ${domains} > "$CERT_DOMAINS_PATH"
}


remove_letsencrypt_certificate(){
  local domain="${1}"
  debug "Removing old certificate for domain ${domain}"
  rm -rf "/etc/letsencrypt/live/${domain}"
  rm -rf "/etc/letsencrypt/archive/${domain}"
  rm -f "/etc/letsencrypt/renewal/${domain}.conf"
  rm -f "$SSL_CERT_PATH" "$SSL_PRIVKEY_PATH"
}


generate_self_signed_certificate(){
  command="openssl req -x509 -newkey rsa:4096 -sha256 -nodes -days 3650"
  command="${command} -out "$SSL_CERT_PATH" -keyout "$SSL_PRIVKEY_PATH""
  command="${command} -subj '/CN=$(get_host_ip)'"
  run_command "${command}" 'Generating self-signed certificate' 'hide_output'
}
