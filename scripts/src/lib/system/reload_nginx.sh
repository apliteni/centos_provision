#!/usr/bin/env bash

reload_nginx(){
  debug "Reload nginx"
  run_command "nginx -s reload" "$(translate 'messages.reload_nginx')" 'hide_output'
}
