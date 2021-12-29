#!/usr/bin/env bash
set -e                              # halt on error
set +m

umask 22

action="${1}"

SUCCESS_RESULT=0
TRUE=0
FAILURE_RESULT=1
FALSE=1
ROOT_UID=0


empty() {
  [[ "${#1}" == 0 ]] && return ${SUCCESS_RESULT} || return ${FAILURE_RESULT}
}

isset() {
  [[ ! "${#1}" == 0 ]] && return ${SUCCESS_RESULT} || return ${FAILURE_RESULT}
}

on() {
  func="$1";
  shift;
  for sig in "$@";
  do
      trap '"$func" "$sig"' "$sig";
  done
}

values() {
  echo "$2"
}

last () {
  [[ -z $1 ]] && return 1;
  eval "${$1[@]:(-1)}"
}

is_ci_mode() {
  [[ "$EUID" != "$ROOT_UID" || "${CI}" != "" ]]
}

is_pipe_mode(){
  [ "${SELF_NAME}" == 'bash' ]
}

TOOL_NAME='kctl-fail2ban'

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.30.3'
VERY_FIRST_VERSION='0.9'
DEFAULT_BRANCH="releases/stable"
BRANCH="${BRANCH:-${DEFAULT_BRANCH}}"

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

declare -A VARS
declare -A ARGS
declare -A DETECTED_VARS

WEBAPP_ROOT="${ROOT_PREFIX}/var/www/keitaro"

KCTL_ROOT="${ROOT_PREFIX}/opt/keitaro"
KCTL_BIN_DIR="${KCTL_ROOT}/bin"
KCTL_LOG_DIR="${KCTL_ROOT}/log"
KCTL_ETC_DIR="${KCTL_ROOT}/etc"
KCTL_WORKING_DIR="${KCTL_ROOT}/tmp"

ETC_DIR="${ROOT_PREFIX}/etc/keitaro"

WORKING_DIR="${ROOT_PREFIX}/var/tmp/keitaro"

LOG_DIR="${ROOT_PREFIX}/var/log/keitaro"
SSL_LOG_DIR="${LOG_DIR}/ssl"

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

CERTBOT_PREFERRED_CHAIN="ISRG Root X1"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

TOOL_ARGS="${*}"

debug() {
  local message="${1}"
  echo "$message" >> "${LOG_PATH}"
  if isset "${ADDITIONAL_LOG_PATH}"; then
    echo "$message" >> "${ADDITIONAL_LOG_PATH}"
  fi
}

disable_jail(){
  debug "Disable jail"
  if [[ ! -L "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}" ]]; then

    if [[ ! -f "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}" ]]; then
        echo  "Jail is already disabled"
        exit 0
    else
      echo  "Jail is not an symlink"
      echo  "Please check the contents of the file ${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}"
      exit 1
    fi;
  else
    rm -f "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}"
  fi;
}

enable_jail(){
  debug "Enable jail"
  if [[ -f "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}" ]]; then

    if [[ -L "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}" ]]; then
        echo  "Jail is already enabled"
        exit 0
    else
      echo  "Jail is not an symlink"
      echo  "Please check the contents of the file ${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}"
      exit 1
    fi;
  else
    ln -s "${ETC_DIR}/fail2ban/${JAIL_FILENAME}" "${FAIL2BAN_JAIL_DIR}/${JAIL_FILENAME}"
  fi;

}

reload_file2ban(){
  debug "Reload file2ban"
  systemctl reload "${FAIL2BAN_SERVICE}"
}

return_fail2ban_status(){
  debug "Return fail2ban status"
  fail2ban-client status
}
  
show_help(){
  debug "Show help"
  echo "Warning: You need to specify an correct action"
  echo "Usage: kctl-fail2ban <enable|disable|status>"
  exit 1
}
FAIL2BAN_ROOT="/etc/fail2ban"
FAIL2BAN_JAIL_DIR="/etc/fail2ban/jail.d"
JAIL_FILENAME="keitaro-jail.conf"
FAIL2BAN_SERVICE="fail2ban.service"

debug "Set first argument to variable"
action=${1}

if [[ "${action}" == "enable" ]]; then
  enable_jail
elif [[ "${action}" == "disable" ]]; then
  disable_jail
elif [[ "${action}" == "status" ]]; then
  return_fail2ban_status
  exit 0
else
  show_help
fi;

reload_file2ban
return_fail2ban_status
