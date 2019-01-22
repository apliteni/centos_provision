#!/usr/bin/env bash

get_host_ip(){
  hostname -I 2>/dev/null | tr ' ' "\n" | grep -oP '(\d+\.){3}\d+' \
    | grep -v '^10\.' | grep -vP '172\.(1[6-9]|2[0-9]|3[1-2])' | grep -v '192\.168\.' \
    | grep -v '127\.' \
    | head -n 1 \
    || true
  }
