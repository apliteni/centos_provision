#!/usr/bin/env bash

init_log(){
  if mkdir -p ${WORKING_DIR} &> /dev/null; then
    > ${SCRIPT_LOG}
  else
    echo "Can't create keitaro working dir ${WORKING_DIR}" >&2
    exit 1
  fi
}
