#!/usr/bin/env bash

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_installed 'nginx' 'errors.reinstall_keitaro'
  assert_server_configuration_relevant
  assert_nginx_configured
}
