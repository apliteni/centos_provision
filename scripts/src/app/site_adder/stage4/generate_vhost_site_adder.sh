#!/usr/bin/env bash

generate_vhost_site_adder(){
  local domain="${1}"
  generate_vhost "$domain" \
    "s|root .*|root ${VARS['site_root']};|" \
    "/locations-tracker.inc/d"
  }
