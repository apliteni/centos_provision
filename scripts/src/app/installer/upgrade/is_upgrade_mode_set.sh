#!/usr/bin/env bash

is_upgrade_mode_set() {
  [[ "${ANSIBLE_TAGS}" =~ upgrade  ]]
}
