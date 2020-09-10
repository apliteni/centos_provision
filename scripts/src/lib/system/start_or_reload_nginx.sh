#!/usr/bin/env bash

start_or_reload_nginx(){
  if is_file_exist "/var/run/nginx.pid" || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "nginx -s reload" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
  fi
}
