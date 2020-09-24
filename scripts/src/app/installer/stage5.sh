#!/usr/bin/env bash

stage5(){
  debug "Starting stage 5: upgrade current and install necessary packages"
  upgrade_packages
  install_packages
}

upgrade_packages(){
  debug "Upgrading packages"
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    run_command "yum update -y"
  else
    run_command "yum update -y --nobest"
  fi
}

install_packages(){
  if ! is_installed tar; then
    install_package tar
  fi
  if ! is_installed ansible; then
    install_package epel-release
    install_package ansible
  fi
}
