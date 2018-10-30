#!/usr/bin/env bash

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_installed 'nginx' 'errors.reinstall_keitaro'
  assert_installed 'crontab' 'errors.reinstall_keitaro'
  assert_installed 'certbot' 'errors.reinstall_keitaro_ssl'
  assert_nginx_configured
  assert_server_configuration_relevant
}
