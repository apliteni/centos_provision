#!/usr/bin/env bash

detect_mime_type(){
  local file="${1}"
  if ! is_installed file "yes"; then
    install_package file > /dev/stderr
  fi
  file --brief --mime-type "$file"
}
