#!/usr/bin/env bash

stage1(){
  debug "Starting stage 1: initial script setup"
  check_thp
  parse_options "$@"
  set_ui_lang
}
