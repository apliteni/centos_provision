#!/usr/bin/env bash

stage1(){
  debug "Starting stage 1: initial script setup"
  if isset "${CI}"; then
    check_thp_disable_possibility
  fi
  parse_options "$@"
  set_ui_lang
}
