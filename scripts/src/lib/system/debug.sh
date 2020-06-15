#!/usr/bin/env bash

debug(){
  local message="${1}"
  echo "$message" >> "${LOG_PATH}"
}
