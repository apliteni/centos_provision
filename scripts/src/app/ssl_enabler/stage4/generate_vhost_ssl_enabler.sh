#!/usr/bin/env bash

generate_vhost_ssl_enabler(){
  local domain="${1}"
  local certs_root_path="/etc/letsencrypt/live/${domain}"
  generate_vhost "$domain" 'messages.generating_nginx_config_for' \
    "s|ssl_certificate .*|ssl_certificate ${certs_root_path}/fullchain.pem;|" \
    "s|ssl_certificate_key .*|ssl_certificate_key ${certs_root_path}/privkey.pem;|"
  }
