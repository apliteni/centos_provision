#!/usr/bin/env bash
#




SHELL_NAME=$(basename "$0")

SUCCESS_RESULT=0
TRUE=0
FAILURE_RESULT=1
FALSE=1
ROOT_UID=0

KEITARO_URL="https://keitaro.io"

RELEASE_VERSION="1.3"
DEFAULT_RELEASE_BRANCH="release-${RELEASE_VERSION}"
RELEASE_BRANCH="${RELEASE_BRANCH:-${DEFAULT_RELEASE_BRANCH}}"

WEBROOT_PATH="/var/www/keitaro"

CONFIG_DIR=".keitaro"
INVENTORY_FILE="${CONFIG_DIR}/installer_config"

NGINX_ROOT_PATH="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_ROOT_PATH}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/keitaro.conf"

SCRIPT_NAME="${TOOL_NAME}.sh"
SCRIPT_URL="${KEITARO_URL}/${TOOL_NAME}.sh"
SCRIPT_LOG="${TOOL_NAME}.log"

REPO_URL="https://raw.githubusercontent.com/apliteni/centos_provision"

CURRENT_COMMAND_OUTPUT_LOG="current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="current_command.error.log"
CURRENT_COMMAND_SCRIPT_NAME="current_command.sh"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

if ! empty ${@}; then
  SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" > run; bash run ${@}"
  TOOL_ARGS="${@}"
else
  SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" > run; bash run"
fi

declare -A VARS

SSL_ENABLER_ERRORS_LOG="${CONFIG_DIR}/ssl_enabler_errors.log"
