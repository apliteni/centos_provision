#!/usr/bin/env bash

UPGRADE_CHECKPOINTS=(0.9 1.4 2.0)

expand_ansible_tags_on_upgrade() {
  if is_upgrade_mode_set; then
    debug "Upgrade mode is detected, setting upgrade helper tags"
    for version in "${UPGRADE_CHECKPOINTS[@]}"; do
      if (( $(as_version ${INSTALLED_VERSION}) <= $(as_version ${version}) )); then
        ANSIBLE_TAGS="${ANSIBLE_TAGS},upgrade_from_${version}"
      fi
    done
    debug "ANSITBLE_TAGS is set to ${ANSIBLE_TAGS}"
  fi
}

