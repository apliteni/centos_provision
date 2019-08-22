#!/usr/bin/env bash

debug(){
  local message="${1}"
  echo "$message" >> "$SCRIPT_LOG"
}
