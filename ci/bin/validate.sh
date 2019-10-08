#!/usr/bin/env bash

ROOT_DIR="."
SCRIPTS_DIR="$ROOT_DIR/scripts"
echo "Validate scripts"
cd $SCRIPTS_DIR

validate_script(){
  if bash -n $1; then
    echo -e "\e[32m$1 OK"
  else
    echo -e "\e[31m$1 Failed"
    exit 1
  fi
}

validate_script install.sh
validate_script enable-ssl.sh
validate_script add-site.sh
validate_script test-run-command.sh
