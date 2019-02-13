#!/usr/bin/env bash

setup_vars(){
  VARS['skip_firewall']='no'
  VARS['ssl']='no'
  VARS['db_root_password']=$(generate_password)
  VARS['db_name']='keitaro'
  VARS['db_user']='keitaro'
  VARS['db_password']=$(generate_password)
  VARS['db_restore']='no'
  VARS['db_restore_path_want_exit']='no'
  VARS['admin_login']='admin'
  VARS['admin_password']=$(generate_password)
  VARS['php_engine']='php-fpm'
}


generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}
