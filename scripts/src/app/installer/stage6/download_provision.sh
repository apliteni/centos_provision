#!/usr/bin/env bash

download_provision(){
  debug "Download provision"
  release_url="https://github.com/apliteni/centos_provision/archive/${BRANCH}.tar.gz"
  run_command "curl -fsSL ${release_url} | tar xz"
}
