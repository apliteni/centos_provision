#!/usr/bin/env bash

vhost_filepath(){
  echo "${NGINX_VHOSTS_DIR}/$(first_domain).conf"
}
