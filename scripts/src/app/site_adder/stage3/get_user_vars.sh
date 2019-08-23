#!/usr/bin/env bash
#





get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  if empty "${VARS['site_domains']}"; then
    get_user_var 'site_domains' 'validate_presence validate_domains_list'
  fi
  VARS['site_domains']="$(to_lower "${VARS['site_domains']}")"
  if empty "${VARS['site_root']}"; then
    VARS['site_root']="/var/www/$(first_domain)"
    get_user_var 'site_root' 'validate_presence'
  fi
}
