#!/usr/bin/env bash

get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  get_user_var 'site_domains' 'validate_presence validate_domains_list'
  VARS['site_root']="/var/www/$(first_domain)"
  get_user_var 'site_root' 'validate_presence'
}
