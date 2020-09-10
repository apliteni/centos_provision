#!/usr/bin/env bash

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.15'
DEFAULT_BRANCH="releases/stable"
BRANCH="${BRANCH:-${DEFAULT_BRANCH}}"

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

WEBAPP_ROOT="${ROOT_PREFIX}/var/www/keitaro"

KCTL_ROOT="${ROOT_PREFIX}/opt/keitaro"
KCTL_BIN_DIR="${KCTL_ROOT}/bin"
KCTL_LOG_DIR="${KCTL_ROOT}/log"
KCTL_ETC_DIR="${KCTL_ROOT}/etc"
KCTL_WORKING_DIR="${KCTL_ROOT}/tmp"

ETC_DIR="${ROOT_PREFIX}/etc/keitaro"

WORKING_DIR="${ROOT_PREFIX}/var/tmp/keitaro"

LOG_DIR="${ROOT_PREFIX}/var/log/keitaro"
LOG_FILENAME="${TOOL_NAME}.log"
LOG_PATH="${LOG_DIR}/${LOG_FILENAME}"

INVENTORY_DIR="${ETC_DIR}/config"
INVENTORY_PATH="${INVENTORY_DIR}/inventory"
DETECTED_INVENTORY_PATH=""

NGINX_CONFIG_ROOT="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_CONFIG_ROOT}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/keitaro.conf"

SCRIPT_NAME="kctl-${TOOL_NAME}"

CURRENT_COMMAND_OUTPUT_LOG="${WORKING_DIR}/current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="${WORKING_DIR}/current_command.error.log"
CURRENT_COMMAND_SCRIPT_NAME="current_command.sh"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

if [[ "${TOOL_NAME}" == "install" ]]; then
  SCRIPT_URL="${KEITARO_URL}/${TOOL_NAME}.sh"
  if ! empty ${@}; then
    SCRIPT_COMMAND="curl -fsSL "$SCRIPT_URL" > run; bash run ${@}"
    TOOL_ARGS="${@}"
  else
    SCRIPT_COMMAND="curl -fsSL "$SCRIPT_URL" > run; bash run"
  fi
else
  if ! empty ${@}; then
    SCRIPT_COMMAND="${SCRIPT_NAME} ${@}"
    TOOL_ARGS="${@}"
  else
    SCRIPT_COMMAND="${SCRIPT_NAME}"
  fi
fi

declare -A VARS
declare -A ARGS
