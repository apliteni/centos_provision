#!/usr/bin/env bash

download_provision(){
  debug "Download provision"
  release_url="https://files.keitaro.io/scripts/${BRANCH}/playbook.tar.gz"
  mkdir -p "${PROVISION_DIRECTORY}"
  run_command "curl -fsSL ${release_url} | tar -xzC ${PROVISION_DIRECTORY}"
}
