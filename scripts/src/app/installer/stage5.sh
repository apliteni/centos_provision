#!/usr/bin/env bash
stage51(){
  debug "Starting stage 5.1: upgrade current packages"
  debug "Installing deltarpm"
  install_package deltarpm
  debug "Upgrading packages"
  run_command "yum update -y"
}


stage52(){
  debug "Starting stage 5.2: install necessary packages"
  if ! is_installed tar; then
    install_package tar
  fi
  if ! is_installed ansible; then
    install_package epel-release
    install_package ansible
    install_package libselinux-python
  fi
}
