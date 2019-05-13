#!/usr/bin/env bash

detect_mime_type(){
  local file="${1}"
  file --brief --mime-type "$file"
}
