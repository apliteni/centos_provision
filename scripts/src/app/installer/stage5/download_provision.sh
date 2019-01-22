#!/usr/bin/env bash

download_provision(){
  debug "Download provision"
  release_url="https://github.com/apliteni/centos_provision/archive/master.tar.gz"
  run_command "curl -sSL "$release_url" | tar xz"
}
