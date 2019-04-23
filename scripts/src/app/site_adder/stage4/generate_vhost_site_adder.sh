#!/usr/bin/env bash

generate_vhost_site_adder(){
  local domain="${1}"
  debug "Add vhost"
  generate_vhost "$domain" 'messages.add_vhost' \
                          "s|root .*|root ${VARS['site_root']};|" \
                          "/locations-tracker.inc/d"
                        }
