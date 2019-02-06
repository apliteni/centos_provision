#!/usr/bin/env bash

download_provision(){
  debug "Download provision"
  release_url="https://github.com/apliteni/centos_provision/archive/${RELEASE_BRANCH}.tar.gz"
  run_command "curl -sSL ${release_url} | tar xz"
}
