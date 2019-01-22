#!/usr/bin/env bash

detect_mime_type(){
  local file="${1}"
  if is_installed "$file"; then
    file --brief --mime-type "$file"
  else
    filename=$(basename "$file")
    extension="${filename##*.}"
    if [[ "$extension" == 'gz' ]]; then
      echo 'application/x-gzip'
    else
      echo 'text/plain'
    fi
  fi
}
