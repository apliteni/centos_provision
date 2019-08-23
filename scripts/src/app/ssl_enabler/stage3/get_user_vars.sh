#!/usr/bin/env bash

get_user_vars() {
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  if empty "${VARS['ssl_domains']}"; then
    get_user_var 'ssl_domains' 'validate_presence validate_domains_list'
  fi
  VARS['ssl_domains']="$(to_lower "${VARS['ssl_domains']}")"
}
