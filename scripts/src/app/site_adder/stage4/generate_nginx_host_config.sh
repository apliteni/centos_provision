#!/usr/bin/env bash

generate_nginx_host_config(){
  local domain="${1}"
  debug "Add vhost"
  generate_vhost "$domain" 'messages.add_vhost' \
                          "s|root .*|root ${VARS['site_root']};|" \
                          "/locations-tracker.inc/d"
                        }
