#!/usr/bin/env bash

remove_log_files(){
  if [[ ! "$PRESERVE_RUNNING" ]]; then
    rm -f "${SCRIPT_LOG}" "${SCRIPT_LOG}.*"
  fi
}
