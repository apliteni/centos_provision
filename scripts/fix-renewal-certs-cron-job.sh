#!/usr/bin/env bash
set -euo pipefail

install_new_job() {
  local renew_cmd='certbot renew --allow-subset-of-names --quiet --renew-hook "systemctl reload nginx"'
  local hour="$(date +'%H')"
  local minute="$(date +'%M')"
  local renew_job="${minute} ${hour} * * * ${renew_cmd}"
  printf 'Installing new schedule . '
  (crontab -l 2>/dev/null; echo "${renew_job}") | crontab - && echo 'OK'
}

remove_old_job() {
  printf 'Removing old schedule . '
  crontab -l -u nginx 2>/dev/null | sed -e '/certbot renew/d' -e '/#Ansible: Renew/d' | crontab -u nginx - && echo 'OK'
}

ensure_caller_is_root() {
  if [[ "${EUID}" != "0" ]]; then
    exit 1;
  fi
}

fix_cron_jobs() {
  ensure_caller_is_root

  if [[ $(crontab -l -u nginx 2>/dev/null | grep 'certbot renew') ]]; then
    remove_old_job

    if [[ ! $(crontab -l 2>/dev/null | grep 'certbot renew') ]]; then
      install_new_job
    else
      echo 'New cron job already installed'
    fi
  else
    echo 'Old cron job already removed'
  fi

}

fix_cron_jobs
