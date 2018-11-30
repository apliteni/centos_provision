#!/usr/bin/env bash
declare -a DOMAINS
declare -a SUCCESSFUL_DOMAINS
declare -a FAILED_DOMAINS
NGINX_SSL_PATH="${NGINX_ROOT_PATH}/ssl"
NGINX_SSL_CERT_PATH="${NGINX_SSL_PATH}/cert.pem"
NGINX_SSL_PRIVKEY_PATH="${NGINX_SSL_PATH}/privkey.pem"
CERT_DOMAINS_PATH="${CONFIG_DIR}/ssl_enabler_cert_domains"
CERTBOT_LOG="${CONFIG_DIR}/ssl_enabler_cerbot.log"
