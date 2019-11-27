#!/usr/bin/env bash
stage5(){
  debug "Starting stage 5: upgrade current and install necessary packages"
  upgrade_packages
  install_packages
}


upgrade_packages(){
  if isset "${VARS['rhel_version']}" && [ "${VARS['rhel_version']}" == "7" ]; then
    install_package deltarpm
  fi
  debug "Upgrading packages"
  run_command "yum update -y"
}


install_packages(){
  if ! is_installed tar; then
    install_package tar
  fi
  if ! is_installed ansible; then
    install_package epel-release
    install_package ansible
    if isset "${VARS['rhel_version']}" && [ "${VARS['rhel_version']}" == "7" ]; then
      install_package libselinux-python
      setenforce enforcing
    else
      install_package python3-libselinux
    fi
  fi
}
