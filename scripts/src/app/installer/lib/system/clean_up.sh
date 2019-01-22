#!/usr/bin/env bash

clean_up(){
  if [ -d "$PROVISION_DIRECTORY" ]; then
    debug "Remove ${PROVISION_DIRECTORY}"
    rm -rf "$PROVISION_DIRECTORY"
  fi
}
