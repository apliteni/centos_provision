#!/usr/bin/env bash

stage4(){
  debug "Starting stage 4: add vhost"
  ensure_can_add_vhost
  for domain in ${VARS['site_domains']//,/ }; do
    add_vhost $domain
  done
  reload_nginx
  show_successful_message
}
