#!/usr/bin/env bash

init_log(){
  if mkdir -p ${CONFIG_DIR} &> /dev/null; then
    > ${SCRIPT_LOG}
  else
    echo "Can't create keitaro config dir ${CONFIG_DIR}" >&2
    exit 1
  fi
}
