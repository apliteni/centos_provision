#!/usr/bin/env bash

stage1(){
  debug "Starting stage 1: initial script setup"
  check_openvz
  check_thp_disable_possibility
  parse_options "$@"
  set_ui_lang
}
