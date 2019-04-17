#!/usr/bin/env bash

generate_nginx_host_config(){
  local domain="${1}"
  debug "Add vhost"
  regenerate_vhost_config "$domain" 'messages.add_vhost' \
                          "s|root .*|root ${VARS['site_root']};|" \
                          "/locations-tracker.inc/d"
                        }
