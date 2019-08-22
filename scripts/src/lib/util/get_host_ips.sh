#!/usr/bin/env bash


get_host_ips(){
  host_ips="$(get_host_ips_internal)"
  if empty "${host_ips}"; then
    host_ips="$(get_host_ips_external)"
  fi
  echo "${host_ips}"
}


get_host_ips_internal(){
  hostname -I 2>/dev/null \
    | tr ' ' "\n" \
    | grep -P '^(\d+\.){3}\d+$' \
    | grep -vP '^10\.' \
    | grep -vP '^172\.(1[6-9]|2[0-9]|3[1-2])\.' \
    | grep -vP '^192\.168\.' \
    | grep -vP '^127\.'
  }


get_host_ips_external(){
  curl -fsSL -4 ifconfig.me 2>/dev/null
}
