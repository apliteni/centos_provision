#!/usr/bin/env bash

add_renewal_job(){
  debug "Add renewal certificates cron job"
  if renewal_job_installed; then
    debug "Renewal cron job already scheduled"
    print_translated 'messages.relevant_renewal_job_already_scheduled'
  else
    schedule_renewal_job
  fi
}


schedule_renewal_job(){
  debug "Schedule renewal job"
  local hour="$(date +'%H')"
  local minute="$(date +'%M')"
  local renew_cmd='certbot renew --allow-subset-of-names --quiet --renew-hook \"systemctl reload nginx\"'
  local renew_job="${minute} ${hour} * * * ${renew_cmd}"
  local schedule_renewal_job_cmd="(crontab -l; echo \"${renew_job}\") | crontab -"
  run_command "${schedule_renewal_job_cmd}" "$(translate 'messages.schedule_renewal_job')" "hide_output"
}


renewal_job_installed(){
  local command="crontab  -l | grep -q 'certbot renew'"
  run_command "${command}" "$(translate 'messages.check_renewal_job_scheduled')" "hide_output uncolored_yes_no" "allow_errors"
}
