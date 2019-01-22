#!/usr/bin/env bash
#





stage4(){
  debug "Starting stage 4: install LE certificates"
  regenerate_self_signed_cert
  generate_certificates
  add_renewal_job
  if isset "$SUCCESSFUL_DOMAINS"; then
    reload_nginx
  fi
  show_finishing_message
}
