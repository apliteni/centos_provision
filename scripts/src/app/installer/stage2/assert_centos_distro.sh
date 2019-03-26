#!/usr/bin/env bash

assert_centos_distro(){
  assert_installed 'yum' 'errors.wrong_distro'
  if ! is_file_exist /etc/centos-release; then
    fail "$(translate errors.wrong_distro)" "see_logs"
    if ! cat /etc/centos-release | grep -q 'release 7\.'; then
      fail "$(translate errors.wrong_distro)" "see_logs"
    fi
  fi
}
