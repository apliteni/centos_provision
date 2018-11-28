#!/usr/bin/env bash
stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_centos_distro
  assert_pannels_not_installed
  assert_apache_not_installed
}
