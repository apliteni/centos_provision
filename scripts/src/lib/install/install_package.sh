#!/usr/bin/env bash

install_package(){
  local package="${1}"
  debug "Installing ${package}"
  run_command "yum install -y ${package}"
}
