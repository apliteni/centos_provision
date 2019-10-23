#!/usr/bin/env bash

stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  check_thp_disable_possibility
  set_ui_lang
}
