#!/usr/bin/env bash

stage4(){
  debug "Starting stage 4: install LE certificates"
  generate_certificates
  if isset "$SUCCESSFUL_DOMAINS"; then
    start_or_reload_nginx
  fi
  show_finishing_message
}
