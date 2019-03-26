#!/usr/bin/env bash
declare -a DOMAINS
declare -a SUCCESSFUL_DOMAINS
declare -a FAILED_DOMAINS
SSL_ROOT="/etc/keitaro/ssl"
SSL_CERT_PATH="${SSL_ROOT}/cert.pem"
SSL_PRIVKEY_PATH="${SSL_ROOT}/privkey.pem"
CERT_DOMAINS_PATH="${CONFIG_DIR}/ssl_enabler_cert_domains"
CERTBOT_LOG="${CONFIG_DIR}/ssl_enabler_cerbot.log"
