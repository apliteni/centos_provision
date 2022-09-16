#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

umask 22


SUCCESS_RESULT=0
TRUE=0
FAILURE_RESULT=1
INTERRUPTED_BY_USER_RESULT=200
INTERRUPTED_ON_PARALLEL_RUN=201
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

is_ci_mode() {
  [[ "$EUID" != "$ROOT_UID" || "${CI}" != "" ]]
}

is_pipe_mode(){
  [ "${SELF_NAME}" == 'bash' ]
}
TOOL_NAME='kctl'

SELF_NAME=${0}


RELEASE_VERSION='2.39.16'
VERY_FIRST_VERSION='0.9'
DEFAULT_BRANCH="releases/stable"
BRANCH="${BRANCH:-${DEFAULT_BRANCH}}"

KEITARO_URL='https://keitaro.io'
FILES_KEITARO_ROOT_URL="https://files.keitaro.io"
FILES_KEITARO_URL="https://files.keitaro.io/scripts/${BRANCH}"

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

declare -A VARS
declare -A ARGS
declare -A DETECTED_VARS

TRACKER_ROOT="${ROOT_PREFIX}/var/www/keitaro"

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
DEFAULT_LOG_PATH="${LOG_DIR}/${LOG_FILENAME}"
if [[ "${KCTLD_MODE}" == "" ]]; then
  LOG_PATH="${LOG_PATH:-${DEFAULT_LOG_PATH}}"
else
  LOG_PATH=/dev/stderr
fi

INVENTORY_DIR="${ETC_DIR}/config"
INVENTORY_PATH="${INVENTORY_DIR}/inventory"
PATH_TO_TRACKER_ENV="${INVENTORY_DIR}/tracker.env"
PATH_TO_KCTLD_ENV="${INVENTORY_DIR}/kctld.env"
DETECTED_INVENTORY_PATH=""

NGINX_CONFIG_ROOT="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_CONFIG_ROOT}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/keitaro.conf"

LETSENCRYPT_DIR="/etc/letsencrypt"

SCRIPT_NAME="kctl-${TOOL_NAME}"

CURRENT_COMMAND_OUTPUT_LOG="${WORKING_DIR}/current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="${WORKING_DIR}/current_command.error.log"
CURRENT_COMMAND_SCRIPT_NAME="current_command.sh"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

TOOL_ARGS="${*}"

DB_ENGINE_INNODB="innodb"
DB_ENGINE_TOKUDB="tokudb"
DB_ENGINE_DEFAULT="${DB_ENGINE_TOKUDB}"

OLAP_DB_MARIADB="mariadb"
OLAP_DB_CLICKHOUSE="clickhouse"
OLAP_DB_DEFAULT="${OLAP_DB_MARIADB}"

TRACKER_STABILITY_STABLE="stable"
TRACKER_STABILITY_UNSTABLE="unstable"
TRACKER_STABILITY_DEFAULT="${TRACKER_STABILITY_STABLE}"

TRACKER_SUPPORTS_RBOOSTER_SINCE='9.14.9.1'

KEITARO_USER='keitaro'
KEITARO_GROUP='keitaro'

TRACKER_CONFIG_FILE="${TRACKER_ROOT}/application/config/config.ini.php"

assert_caller_root(){
  debug 'Ensure current user is root'
  if [[ "$EUID" == "$ROOT_UID" ]]; then
    debug 'OK: current user is root'
  else
    debug 'NOK: current user is not root'
    fail "$(translate errors.must_be_root)"
  fi
  
}


assert_installed(){
  local program="${1}"
  local error="${2}"
  if ! is_installed "$program"; then
    fail "$(translate "${error}")"
  fi
}

USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE="2.12"
KEITARO_LOCK_FILEPATH="${TRACKER_ROOT}/var/install.lock"

assert_keitaro_not_installed() {
  debug 'Ensure keitaro is not installed yet'
  if is_keitaro_installed; then
    debug 'NOK: keitaro is already installed'
    print_with_color "$(translate messages.keitaro_already_installed)" 'yellow'
    clean_up
    print_url
    exit "${KEITARO_ALREADY_INSTALLED_RESULT}"
  else
    debug 'OK: keitaro is not installed yet'
  fi
}

is_keitaro_installed() {
   if isset "${VARS['installed']}"; then
     debug "installed flag is set"
     return ${SUCCESS_RESULT}
   fi
   if use_old_algorithm_for_installation_check; then
     debug "Current version is ${INSTALLED_VERSION} - using old algorithm (check '${KEITARO_LOCK_FILEPATH}' file)"
     if file_exists "${KEITARO_LOCK_FILEPATH}"; then
       return ${SUCCESS_RESULT}
     fi
   fi
   return ${FAILURE_RESULT}
}

use_old_algorithm_for_installation_check() {
  (( $(as_version "${INSTALLED_VERSION}") <= $(as_version "${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE}") ))
}
assert_no_another_process_running(){

  exec 8>/var/run/${SCRIPT_NAME}.lock

  debug "Check if another process is running"

  if flock -n -x 8; then
    debug "No other installer process is running"
  else
    fail "$(translate 'errors.already_running')" "${INTERRUPTED_ON_PARALLEL_RUN}"
  fi
}
# Check if lock file exist
#https://certbot.eff.org/docs/using.html#id5
#
assert_that_another_certbot_process_not_runing() {
  debug
  if [ -f "${CERTBOT_LOCK_FILE}" ]; then
    debug "Find lock file, raise error"
    fail "$(translate 'certbot_errors.another_proccess')"
  else
    debug "another certbot proccess not running"
  fi

}

directory_exists(){
  local directory="${1}"
  debug "Checking ${directory} directory existence"
  if [ -d "${directory}" ]; then
    debug "YES: ${directory} directory exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${directory} directory does not exist"
    return ${FAILURE_RESULT}
  fi
}

file_content_matches(){
  local file="${1}"
  local mode="${2}"
  local pattern="${3}"
  debug "Checking ${file} file matching with pattern '${pattern}'"
  if test -f "$file" && grep -q "${mode}" "$pattern" "$file"; then
    debug "YES: ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not match '${pattern}"
    return ${FAILURE_RESULT}
  fi
}

file_exists(){
  local file="${1}"
  debug "Checking ${file} file existence"
  if [ -f "${file}" ]; then
    debug "YES: ${file} file exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not exist"
    return ${FAILURE_RESULT}
  fi
}

build_certbot_command() {
  echo "/opt/keitaro/bin/kctl run certbot"
}


translate(){
  local key="${1}"
  local i18n_key="en.${key}"
  message="${DICT[$i18n_key]}"
  while isset "${2}"; do
    message=$(interpolate "${message}" "${2}")
    shift
  done
  echo "$message"
}


interpolate(){
  local string="${1}"
  local substitution="${2}"
  IFS="=" read -r name value <<< "${substitution}"
  string="${string//:${name}:/${value}}"
  echo "${string}"
}

add_indentation(){
  sed -r "s/^/$INDENTATION_SPACES/g"
}

detect_mime_type(){
  local file="${1}"
  file --brief --mime-type "$file"
}

get_user_var(){
  local var_name="${1}"
  local validation_methods="${2}"
  print_prompt_help "$var_name"
  while true; do
    print_prompt "$var_name"
    value="$(read_stdin)"
    debug "$var_name: got value '${value}'"
    if ! empty "$value"; then
      VARS[$var_name]="${value}"
    fi
    error=$(get_error "${var_name}" "$validation_methods")
    if isset "$error"; then
      debug "$var_name: validation error - '${error}'"
      print_prompt_error "$error"
      VARS[$var_name]=''
    else
      if [[ "$validation_methods" =~ 'validate_yes_no' ]]; then
        transform_to_yes_no "$var_name"
      fi
      debug "  ${var_name}=${VARS[${var_name}]}"
      break
    fi
  done
}
hack_stdin_if_pipe_mode(){
  if is_pipe_mode; then
    debug 'Detected pipe bash mode. Stdin hack enabled'
    hack_stdin
  else
    debug "Can't detect pipe bash mode. Stdin hack disabled"
  fi
}


hack_stdin(){
  exec 3<&1
}
#





print_prompt(){
  local var_name="${1}"
  prompt=$(translate "prompts.$var_name")
  prompt="$(print_with_color "$prompt" 'bold')"
  if ! empty "${VARS[$var_name]}"; then
    prompt="$prompt [${VARS[$var_name]}]"
  fi
  echo -en "$prompt > "
}
print_prompt_error(){
  local error_key="${1}"
  error=$(translate "validation_errors.$error_key")
  print_with_color "*** ${error}" 'red'
}

print_prompt_help(){
  local var_name="${1}"
  print_translated "prompts.$var_name.help"
}

read_stdin(){
  if is_pipe_mode; then
    read -r -u 3 variable
  else
    read -r variable
  fi
  echo "$variable"
}

clean_up(){
  debug 'called clean_up()'
}

debug() {
  local message="${1}"
  echo "$message" >> "${LOG_PATH}"
  if isset "${ADDITIONAL_LOG_PATH}"; then
    echo "$message" >> "${ADDITIONAL_LOG_PATH}"
  fi
}

expand_ansible_tags_with_tag() {
  local tag="${1}"
  local tag_regex="\<${tag}\>"
  if [[ "${ANSIBLE_TAGS}" =~ ${tag_regex} ]]; then
    return
  fi
  if empty "${ANSIBLE_TAGS}"; then
    ANSIBLE_TAGS="${tag}"
  else
    ANSIBLE_TAGS="${tag},${ANSIBLE_TAGS}"
  fi
}

fail() {
  local message="${1}"
  local exit_code="${2-${FAILURE_RESULT}}"
  log_and_print_err "*** $(translate errors.program_failed) ***"
  log_and_print_err "$message"
  print_err
  if [[ "${exit_code}" != "${INTERRUPTED_ON_PARALLEL_RUN}" ]]; then
    clean_up
  fi
  exit "${exit_code}"
}

common_parse_options(){
  local option="${1}"
  local argument="${2}"
  case $option in
    l|L)
      print_deprecation_warning '-L option is ignored'
      ;;
    v)
      version
      ;;
    h)
      help
      ;;
    *)
      wrong_options
      ;;
  esac
}


help(){
  usage_en_header
  help_en
  help_en_common
  help_en_variables
  exit ${SUCCESS_RESULT}
}


usage(){
  usage_en
  exit ${FAILURE_RESULT}
}


version(){
  echo "${SCRIPT_NAME} v${RELEASE_VERSION}"
  exit ${SUCCESS_RESULT}
}


wrong_options(){
  WRONG_OPTIONS="wrong_options"
}


ensure_options_correct(){
  if isset "${WRONG_OPTIONS}"; then
    usage
  fi
}


usage_en(){
  usage_en_header
  echo "Try '${SCRIPT_NAME} -h' for more information."
  echo
}

usage_en_header(){
  echo "Usage: ${SCRIPT_NAME} [OPTION]..."
  echo
}

help_en_common(){
  echo "Miscellaneous:"
  echo "  -h                       display this help text and exit"
  echo
  echo "  -v                       display version information and exit"
  echo
}

help_en_variables(){
  echo  "Environment variables:"
  echo 
  echo  "  TRACKER_STABILITY       Set up stability channel stable|unstsable. Default: stable"
  echo
}

init() {
  init_kctl
  debug "Starting init stage: log basic info"
  debug "Command: ${SCRIPT_NAME} ${TOOL_ARGS}"
  debug "Script version: ${RELEASE_VERSION}"
  debug "User ID: ${EUID}"
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGTERM
  trap on_exit_by_user_interrupt SIGINT
}

LOGS_TO_KEEP=5

is_logging_to_file() {
  [[ ! "${LOG_PATH}" =~ ^/dev/ ]]
}

init_kctl() {
  init_kctl_dirs_and_links
  if is_logging_to_file; then
    init_log "${LOG_PATH}"
  fi
}

init_kctl_dirs_and_links() {
  if [[ ! -d "${KCTL_ROOT}" ]]; then
    if ! create_kctl_dirs_and_links; then
      echo "Can't create keitaro directories" >&2
      exit 1
    fi
  fi
  if [[ ! -d "${WORKING_DIR}" ]]; then
    if ! mkdir -p "${WORKING_DIR}"; then
      echo "Can't create keitaro working directory ${WORKING_DIR}" >&2
      exit 1
    fi
  fi
}

create_kctl_dirs_and_links() {
  mkdir -p "${LOG_DIR}" "${SSL_LOG_DIR}" "${INVENTORY_DIR}" "${KCTL_BIN_DIR}" "${WORKING_DIR}" &&
    chmod 0750 "${ETC_DIR}" &&
    ln -s "${ETC_DIR}" "${KCTL_ETC_DIR}" &&
    ln -s "${LOG_DIR}" "${KCTL_LOG_DIR}" &&
    ln -s "${WORKING_DIR}" "${KCTL_WORKING_DIR}"
}

init_log() {
  local log_path="${1}"
  save_previous_log "${log_path}"
  delete_old_logs "${log_path}"
  create_log "${log_path}"
}

save_previous_log() {
  local log_path="${1}"
  local previous_log_timestamp
  if [[ -f "${log_path}" ]]; then
    previous_log_timestamp=$(date -r "${log_path}" +"%Y%m%d%H%M%S")
    mv "${log_path}" "${log_path}-${previous_log_timestamp}"
  fi
}

delete_old_logs() {
  local log_filepath="${1}"
  local log_dir
  local log_filename
  log_dir="$(dirname "${log_filepath}")"
  log_filename="$(basename "${log_filepath}")"
  /usr/bin/find "${log_dir}" -name "${log_filename}-*" | \
    /usr/bin/sort | \
    /usr/bin/head -n -${LOGS_TO_KEEP} | \
    /usr/bin/xargs rm -f
}

create_log() {
  local log_path="${1}"
  if [[ "${TOOL_NAME}" == "install" ]] && ! is_ci_mode; then
    (umask 066 && touch "${log_path}")
  else
    touch "${log_path}"
  fi
}

log_and_print_err(){
  local message="${1}"
  print_err "$message" 'red'
  debug "$message"
}

on_exit(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')"
}

on_exit_by_user_interrupt(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')" "${INTERRUPTED_BY_USER_RESULT}"
}

print_content_of(){
  local filepath="${1}"
  if [ -f "$filepath" ]; then
    if [ -s "$filepath" ]; then
      echo "Content of '${filepath}':"
      cat "$filepath" | add_indentation
    else
      debug "File '${filepath}' is empty"
    fi
  else
    debug "Can't show '${filepath}' content - file does not exist"
  fi
}
print_deprecation_warning() {
  local message="${1}"
  print_err "DEPRECATION WARNING: ${message}" "yellow"
}

print_err(){
  local message="${1}"
  local color="${2}"
  print_with_color "$message" "$color" >&2
}

print_translated(){
  local key="${1}"
  message=$(translate "${key}")
  if ! empty "$message"; then
    echo "$message"
  fi
}

declare -A COLOR_CODE

COLOR_CODE['bold']=1

COLOR_CODE['default']=39
COLOR_CODE['red']=31
COLOR_CODE['green']=32
COLOR_CODE['yellow']=33
COLOR_CODE['blue']=34
COLOR_CODE['magenta']=35
COLOR_CODE['cyan']=36
COLOR_CODE['grey']=90
COLOR_CODE['light.red']=91
COLOR_CODE['light.green']=92
COLOR_CODE['light.yellow']=99
COLOR_CODE['light.blue']=94
COLOR_CODE['light.magenta']=95
COLOR_CODE['light.cyan']=96
COLOR_CODE['light.grey']=37

RESET_FORMATTING='\e[0m'

print_with_color(){
  local message="${1}"
  local color="${2}"
  if ! empty "$color"; then
    escape_sequence="\e[${COLOR_CODE[$color]}m"
    echo -e "${escape_sequence}${message}${RESET_FORMATTING}"
  else
    echo "$message"
  fi
}

REMOVE_COLORS_SED_REGEX="s/\x1b\[([0-9]{1,3}(;[0-9]{1,3}){,2})?[mGK]//g"

run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local print_fail_message_method="${6}"
  local output_log="${7}"
  debug "Evaluating command: ${command}"
  if empty "$message"; then
    run_command_message=$(print_with_color "$(translate 'messages.run_command')" 'blue')
    message="$run_command_message \`$command\`"
  else
    message=$(print_with_color "${message}" 'blue')
  fi
  if isset "$hide_output"; then
    echo -en "${message} . "
  else
    echo -e "${message}"
  fi
  really_run_command "${command}" "${hide_output}" "${allow_errors}" "${run_as}" \
                     "${print_fail_message_method}" "${output_log}"
}


print_command_status(){
  local command="${1}"
  local status="${2}"
  local color="${3}"
  local hide_output="${4}"
  debug "Command result: ${status}"
  if isset "$hide_output"; then
    if [[ "$hide_output" =~ (uncolored_yes_no) ]]; then
      print_uncolored_yes_no "$status"
    else
      print_with_color "$status" "$color"
    fi
  fi
}


print_uncolored_yes_no(){
  local status="${1}"
  if [[ "$status" == "NOK" ]]; then
    echo "NO"
  else
    echo "YES"
  fi
}



really_run_command(){
  local command="${1}"
  local hide_output="${2}"
  local allow_errors="${3}"
  local run_as="${4}"
  local print_fail_message_method="${5}"
  local output_log="${6}"
  local evaluated_command
  local current_command_script
  current_command_script=$(save_command_script "${command}" "${run_as}")
  evaluated_command=$(command_run_as "${current_command_script}" "${run_as}")
  evaluated_command=$(unbuffer_streams "${evaluated_command}")
  evaluated_command=$(save_command_logs "${evaluated_command}" "${output_log}")
  evaluated_command=$(hide_command_output "${evaluated_command}" "${hide_output}")
  debug "Real command: ${evaluated_command}"
  if ! eval "${evaluated_command}"; then
    print_command_status "${command}" 'NOK' 'red' "${hide_output}"
    if isset "$allow_errors"; then
      remove_current_command "$current_command_script"
      return ${FAILURE_RESULT}
    else
      fail_message=$(print_current_command_fail_message "$print_fail_message_method" "$current_command_script")
      remove_current_command "$current_command_script"
      fail "${fail_message}"
    fi
  else
    print_command_status "$command" 'OK' 'green' "$hide_output"
    remove_current_command "$current_command_script"
  fi
}


command_run_as(){
  local command="${1}"
  local run_as="${2}"
  if isset "$run_as"; then
    echo "sudo -u '${run_as}' bash -c '${command}'"
  else
    echo "bash ${command}"
  fi
}


unbuffer_streams(){
  local command="${1}"
  echo "stdbuf -i0 -o0 -e0 ${command}"
}


save_command_logs(){
  local evaluated_command="${1}"
  local output_log="${2}"
  local remove_colors="sed -r -e '${REMOVE_COLORS_SED_REGEX}'"
  save_output_log="tee -i ${CURRENT_COMMAND_OUTPUT_LOG} | tee -ia >(${remove_colors} >> ${LOG_PATH})"
  save_error_log="tee -i ${CURRENT_COMMAND_ERROR_LOG} | tee -ia >(${remove_colors} >> ${LOG_PATH})"
  if isset "${output_log}"; then
    save_output_log="${save_output_log} | tee -ia ${output_log}"
    save_error_log="${save_error_log} | tee -ia ${output_log}"
  fi
  echo "((${evaluated_command}) 2> >(${save_error_log}) > >(${save_output_log}))"
}


remove_colors_from_file(){
  local file="${1}"
  debug "Removing colors from file ${file}"
  sed -r -e "${REMOVE_COLORS_SED_REGEX}" -i "$file"
}


hide_command_output(){
  local command="${1}"
  local hide_output="${2}"
  if isset "$hide_output"; then
    echo "${command} > /dev/null"
  else
    echo "${command}"
  fi
}


save_command_script(){
  local command="${1}"
  local run_as="${2}"
  local current_command_dir
    current_command_dir=$(mktemp -d)
  if isset "$run_as"; then
    chown "$run_as" "$current_command_dir"
  fi
  local current_command_script="${current_command_dir}/${CURRENT_COMMAND_SCRIPT_NAME}"
  echo '#!/usr/bin/env bash' > "${current_command_script}"
  echo 'set -o pipefail' >> "${current_command_script}"
  echo -e "${command}" >> "${current_command_script}"
  debug "$(print_content_of "${current_command_script}")"
  echo "${current_command_script}"
}


print_current_command_fail_message(){
  local print_fail_message_method="${1}"
  local current_command_script="${2}"
  remove_colors_from_file "${CURRENT_COMMAND_OUTPUT_LOG}"
  remove_colors_from_file "${CURRENT_COMMAND_ERROR_LOG}"
  if empty "$print_fail_message_method"; then
    print_fail_message_method="print_common_fail_message"
  fi
  local fail_message
  local fail_message_header
  fail_message_header=$(translate 'errors.run_command.fail')
  fail_message=$(eval "$print_fail_message_method" "$current_command_script")
  echo -e "${fail_message_header}\n${fail_message}"
}


print_common_fail_message(){
  local current_command_script="${1}"
  print_content_of "${current_command_script}"
  print_tail_content_of "${CURRENT_COMMAND_OUTPUT_LOG}"
  print_tail_content_of "${CURRENT_COMMAND_ERROR_LOG}"
}


print_tail_content_of(){
  local file="${1}"
  MAX_LINES_COUNT=20
  print_content_of "${file}" |  tail -n "$MAX_LINES_COUNT"
}


remove_current_command(){
  local current_command_script="${1}"
  debug "Removing current command script and logs"
  rm -f "$CURRENT_COMMAND_OUTPUT_LOG" "$CURRENT_COMMAND_ERROR_LOG" "$current_command_script"
  rmdir "$(dirname "$current_command_script")"
}

PATH_TO_NGINX_PIDFILE="/var/run/nginx.pid"

start_or_reload_nginx(){
  if podman exec nginx test -f "${PATH_TO_NGINX_PIDFILE}" || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "systemctl reload nginx" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
  fi
}

TRACKER_VERSION_PHP="${TRACKER_ROOT}/version.php"

get_tracker_version() {
  if file_exists "${TRACKER_VERSION_PHP}"; then
    cut -d "'" -f 2 "${TRACKER_VERSION_PHP}"
  fi
}

tracker_supports_rbooster() {
  (( $(as_version "$(get_tracker_version)") >= $(as_version "${TRACKER_SUPPORTS_RBOOSTER_SINCE}") ))
}

get_error(){
  local var_name="${1}"
  local validation_methods_string="${2}"
  local value="${VARS[$var_name]}"
  local error=""
  read -ra validation_methods <<< "$validation_methods_string"
  for validation_method in "${validation_methods[@]}"; do
    if ! eval "${validation_method} '${value}'"; then
      debug "${var_name}: '${value}' invalid for ${validation_method} validator"
      error="${validation_method}"
      break
    else
      debug "${var_name}: '${value}' valid for ${validation_method} validator"
    fi
  done
  echo "${error}"
}
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='Please run this program as root.'
DICT['en.errors.upgrade_server']='You should upgrade the server configuration. Please contact Keitaro support team.'
DICT['en.errors.run_command.fail']='There was an error evaluating current command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.errors.unexpected']='Unexpected error'
DICT['en.errors.cant_upgrade']='Cannot upgrade because installation process is not finished yet'
DICT['en.certbot_errors.another_proccess']="Another certbot process is already running"
DICT['en.messages.generating_nginx_vhost']="Generating nginx config for domain :domain:"
DICT['en.messages.reloading_nginx']="Reloading nginx"
DICT['en.messages.nginx_is_not_running']="Nginx is not running"
DICT['en.messages.starting_nginx']="Starting nginx"
DICT['en.messages.skip_nginx_conf_generation']="Skip nginx config generation"
DICT['en.messages.run_command']='Evaluating command'
DICT['en.messages.successful']='Everything is done!'
DICT['en.no']='no'
DICT['en.validation_errors.validate_domains_list']=$(cat <<-END
	Please enter domains list, separated by comma without spaces (eg domain1.tld,www.domain1.tld).
	Each domain name should consist of only letters, numbers and hyphens and contain at least one dot.
	Domains longer than 64 characters are not supported.
END
)
DICT['en.validation_errors.validate_presence']='Please enter value'
DICT['en.validation_errors.validate_absence']='Should not be specified'
DICT['en.validation_errors.validate_yes_no']='Please answer "yes" or "no"'

kctl_auto_install(){
  local install_exit_code
  local sleeping_message
  local install_args="${1}"
  local log_file="${2}"
  local tags="${3}"
  
  if empty "${KCTLD_MODE}"; then
    for (( count=0; count<=${#RETRY_INTERVALS[@]}; count++ ));  do
      if kctl_install "${install_args}" "${log_file}" "${tags}"; then
        installator_exit_code="${?}"
      else
        installator_exit_code="${?}"
      fi
      debug "Result code is '${installator_exit_code}'"
  
      if [[ "${installator_exit_code}" == "0" ]]; then
        return "${SUCCESS_RESULT}"
      fi
  
      if (( "${installator_exit_code}" >= "200" )); then
        return "${installator_exit_code}"
      fi
  
      if [[ "$count" == "${#RETRY_INTERVALS[@]}" ]]; then
        fail "$(translate errors.unexpected)"
      else
        sleeping_message="$(translate "messages.sleeping_before_next_try" "retry_interval=${RETRY_INTERVALS[$count]}")"
        echo "${sleeping_message}" >&2
        debug "${sleeping_message}"
        sleep "${RETRY_INTERVALS[$count]}"
      fi
    done
  else
    kctl_install "${install_args}" "${log_file}" "${tags}"
  fi
}

kctl_install(){
  local install_args="${1}"
  local log_file="${2}"
  local tags="${3}"

  if  empty "$tags"; then
    debug "Running \`curl -fsSL4 '${FILES_KEITARO_URL}/install.sh' | bash -s -- ${install_args} -o '${KCTL_LOG_DIR}/${log_file}' \`"
    get_kctl_install | bash -s -- "${install_args}" -o "${KCTL_LOG_DIR}/${log_file}"
  else
    debug "Running \`curl -fsSL4 '${FILES_KEITARO_URL}/install.sh' | bash -s -- ${install_args} -t ${tags} -o '${KCTL_LOG_DIR}/${log_file}' \`"
    get_kctl_install | bash -s -- "${install_args}" -t "${tags}" -o "${KCTL_LOG_DIR}/${log_file}"
  fi
}

kctl_install_tracker() {
  local tracker_version_to_install="${1}"
  local log_path="${KCTL_LOG_DIR}/kctl-install-tracker.log"

  assert_tracker_version_to_install_valid "${tracker_version_to_install}"

  debug "curl -fsSL4 '${FILES_KEITARO_URL}/install.sh' | bash -s -- -U -a ${tracker_version_to_install} -o ${log_path}"
  get_kctl_install | bash -s -- -U -a "${tracker_version_to_install}" -o "${log_path}"
}

assert_tracker_version_to_install_valid() {
  local tracker_version_to_install="${1}"

  if [[ "$tracker_version_to_install" =~ ^https:\/\/files.keitaro.io\/ ]]; then
    return
  fi
  if empty "${tracker_version_to_install}"; then
    fail "$(translate 'errors.tracker_version_to_install_is_empty')"
  fi
  if ! is_tracker_version_to_install_valid "${tracker_version_to_install}"; then
    fail "$(translate errors.tracker_version_to_install_is_incorrect)"
  fi
}

is_tracker_version_to_install_valid() {
  local tracker_version_to_install="${1}"
  [[ "${tracker_version_to_install}" == "latest" ]] || \
    [[ "${tracker_version_to_install}" == "latest-stable" ]] || \
    [[ "${tracker_version_to_install}" == "latest-unstable" ]] || \
    (( $(as_version "${tracker_version_to_install}") >=  $(as_version "${MIN_TRACKER_VERSION_TO_INSTALL}") ))
}

kctl_rescue() {
  debug "curl -fsSL4 '${FILES_KEITARO_URL}/install.sh' | | bash -s -- -C -o ${KCTL_LOG_DIR}/kctl-rescue.log"
  get_kctl_install | bash -s -- -C -o "${KCTL_LOG_DIR}/kctl-rescue.log"
}
kctl_reset() {
  reset_tracker_salt
  reset_license_ip
  reset_machine_id
  reset_mysql_password "keitaro"
  reset_mysql_password "root"
  reset_ch_password
}

kctl_show_help(){
  echo "kctl - Keitaro management tool"
  echo ""
  cat <<-END
Usage:

  kctl [module] [action] [options]

Example:

  kctl install

Actions:
   kctl install                           - install and tune tracker and system components
   kctl upgrade                           - upgrades system & tracker
   kctl rescue                            - fixes common problems
   kctl downgrade [version]               - downgrades tracker to version (by default downgrades to latest stable version)
   kctl install-tracker <version>         - installs tracker with specified version

Modules:
   kctl certificates                      - manage LE certificates
   kctl features                          - manage features
   kctl podman                            - manage podman containers
   kctl resolvers                         - manage DNS resolvers
   kctl transfers                         - manage tracker data transfers
   kctl run                               - simplifies running dockerized commands

Environment variables:

  TRACKER_STABILITY                       - Set up stability channel stable|unstsable. Default: stable

END
}

kctl_show_version(){
  read_inventory
  detect_installed_version
  if is_keitaro_installed; then
    translate 'messages.kctl_version' "kctl_version=${RELEASE_VERSION}"
    translate 'messages.kctl_tracker' "tracker_version=$(get_tracker_version)"
  else
    fail "$(translate 'errors.tracker_is_not_installed')"
  fi
}

on_exit(){
  exit 1
}

get_kctl_install() {
  curl -fsSL4 "${FILES_KEITARO_URL}/install.sh"
}

kctl_run() {
  local action="${1}"
  shift

  case "${action}" in
    clickhouse-client)
      kctl_run_clickhouse_client
      ;;
    clickhouse-query)
      kctl_run_clickhouse_query  "${@}"
      ;;
    mariadb-client | mysql-client)
      kctl_run_mysql_client
      ;;
    mariadb-query | mysql-query)
      kctl_run_mysql_query "${@}"
      ;;
    cli-php)
      kctl_run_cli_php "${@}"
      ;;
    redis-client)
      kctl_run_redis_client "${@}"
      ;;
    nginx)
      kctl_run_nginx "${@}"
      ;;
    certbot)
      kctl_run_certbot "${@}"
      ;;
    help)
      kctl_run_usage
      ;;
    *)
      kctl_run_usage
      exit 1
      ;;
  esac
}

kctl_certificates() {
  local action="${1}"; shift
  case "${action}" in
    issue)
      kctl_certificates.issue "${@}"
      ;;
    revoke)
      kctl_certificates.revoke "${@}"
      ;;
    prune)
      kctl_certificates.prune "${@}"
      ;;
    renew)
      kctl_certificates.renew
      ;;
    remove-old-logs)
      kctl_certificates.remove_old_logs
      ;;
    fix-x3-expiration)
      kctl_certificates.fix_x3_expiration
      ;;
    *)
      kctl_certificates_usage
  esac
}

kctl_podman() {
  local action="${1}"
  shift

  case "${action}" in
    prune)
      if [[ "${#}" != 1 ]]; then
        kctl_podman.usage
      else
        kctl_podman.prune "${1}"
      fi
      ;;
    stats)
      podman stats --no-stream --format json
      ;;
    help)
      kctl_podman.usage
      ;;
    *)
      kctl_podman
      exit 1
      ;;
  esac
}

kctl_certificates_usage() {
  echo "Usage:"
  echo "  kctl certificates issue domain1.tld domain2.tld ...     issue LE certificates for specified domains"
  echo "  kctl certificates revoke domain1.tld domain2.tld ...    revoke LE certificates for specified domains"
  echo "  kctl certificates prune abandoned                       removes LE certificates without appropriate nginx configs"
  echo "  kctl certificates prune broken                          removes nginx domains with inconsistent LE certificates"
  echo "  kctl certificates prune detached                        removes nginx domains are not presented in the Keitaro DB"
  echo "  kctl certificates prune safe                            removes abandoned & broken certificates"
  echo "  kctl certificates prune all                             removes abandoned, broken & detached certificates"
  echo "  kctl certificates renew                                 renew LE certificates"
  echo "  kctl certificates remove-old-logs                       remove old issuing logs"
  echo
  echo "Supported features: ${SUPPORTED_FEATURES[*]}"
  echo
}

kctl_certificates.prune() {
  /opt/keitaro/bin/kctl-certificates-prune "${@}"
}

PEM_SPLITTER="-----BEGIN CERTIFICATE-----"

kctl_certificates.fix_x3_expiration() {
  local live_certificate_filepaths
  local temporary_dir
  local certificate_chain_without_x3
  live_certificate_filepaths=$(get_live_certificate_filepaths)
  for certificate_path in $live_certificate_filepaths; do
    if is_last_certificate_issued_by_x3 "${certificate_path}"; then
      debug "Certificate chain ${certificate_path} contains a certificate from X3, removing X3 from the chain"
      backup_certificate "${certificate_path}"
      remove_last_certificate_from_chain "${certificate_path}"
    else
      debug "Certificate chain ${certificate_path} does not contain a certificate from X3, wont modify the chain"
    fi
  done
}


get_live_certificate_filepaths(){
  if [[ -d /etc/letsencrypt/live/ ]]; then
    find /etc/letsencrypt/live/ -name fullchain.pem -print0 | xargs -0 readlink -f
  fi
}


backup_certificate(){
  local certificate_path="${1}"
  local domain_name
  local backup_directory
  domain_name=$(basename "$(dirname "${certificate_path}")")
  backup_directory="/etc/keitaro/backups/letsencrypt/${CURRENT_DATETIME}/${domain_name}"

  mkdir -p "${backup_directory}"
  #copy old certificate to backup
  cp "${certificate_path}" "${backup_directory}"
  debug "Certificates chain for ${domain_name} was saved to ${backup_directory}"
}


is_last_certificate_issued_by_x3() {
  local certificate_path="${1}"
  local chain_content
  chain_content="$(< "${certificate_path}")"
  local last_certificate_content="${PEM_SPLITTER}${chain_content##*"${PEM_SPLITTER}"}"
  echo "$last_certificate_content" | openssl x509 -text | grep 'Issuer' | grep 'DST Root CA X3' -q
}


remove_last_certificate_from_chain() {
  local certificate_path="${1}"
  local certificate_chain_content
  certificate_chain_content="$(< "${certificate_path}")"
  local certificate_chain_wo_x3_content="${certificate_chain_content%"${PEM_SPLITTER}"*}"
  echo "${certificate_chain_wo_x3_content}" > "${certificate_path}"
}

kctl_certificates.remove_old_logs() {
  /usr/bin/find /var/log/keitaro/ssl -mtime +30 -type f -delete
}

kctl_certificates.renew() {
  local successfully_renewed_flag_filepath="/var/lib/letsencrypt/.renewed"
  local renew_args="--allow-subset-of-names --renew-hook 'touch ${successfully_renewed_flag_filepath}'"
  local message="Renewing LE certificates"
  local log_path="${LOG_DIR}/${TOOL_NAME}-renew-certificates.log"
  local command

  command="$(build_certbot_command) renew ${renew_args}"
  LOG_PATH="${log_path}"
  init_log "${log_path}"

  debug "Renewing certificates"

  run_command "${command}" "${message}" 'hide_output' 'allow_errors' || \
    debug "Errors occurred while renewing some certificates. certbot exit code: ${?}"

  if file_exists "${successfully_renewed_flag_filepath}"; then
    debug "Some certificates have been renewed. Removing flag file ${successfully_renewed_flag_filepath} and reloading nginx"
    command="rm -f '${successfully_renewed_flag_filepath}' && systemctl reload nginx"
    run_command "${command}" "" 'hide_output'
  else
    debug "Certificates have not been updated."
  fi
}

kctl_certificates.issue() {
  local domains="${*}"
  /opt/keitaro/bin/kctl-enable-ssl -D "${domains// /,}"
}

kctl_certificates.revoke() {
  local domains="${*}"
  /opt/keitaro/bin/kctl-disable-ssl -D "${domains// /,}"
}

DNS_GOOGLE="8.8.8.8"
RESOLV_CONF=/etc/resolv.conf

kctl_resolvers() {
  local action="${1}"
  case "${action}" in
    set-google)
      kctl_resolvers_set_google
      ;;
    reset)
      kctl_resolvers_reset
      ;;
    *)
      kctl_resolvers_usage
  esac
}

kctl_podman.usage(){
  echo "Usage:"
  echo "  kctl podman prune CONTAINTER_NAME              removes container and storage assotiated with it"
  echo "  kctl podman statistics [--format json]         prints statistics"
  echo "  kctl podman usage                              prints this info"
}

PATH_TO_CONTAINERS_JSON="/var/lib/containers/storage/overlay-containers/containers.json"

kctl_podman.prune() {
  local container_name="${1}"
  if podman ps -a --format json | grep -q -F "\"Names\": \"${container_name}\""; then
    echo "Removing running ${container_name} container"
    podman rm --force "${container_name}"
  fi
  if grep -q -F "\"names\":[\"${container_name}\"]" "${PATH_TO_CONTAINERS_JSON}"; then
    echo "Removing ${container_name} container's storage"
    podman rm --force --storage "${container_name}"
  fi
}

kctl_run_certbot() {
  # shellcheck source=/dev/null
  source /etc/keitaro/config/components.env

  /usr/bin/podman run \
                  --network host \
                  --rm \
                  --volume /etc/letsencrypt:/etc/letsencrypt \
                  --volume /var/lib/letsencrypt:/var/lib/letsencrypt \
                  --volume /var/log/letsencrypt:/var/log/letsencrypt \
                  --volume /var/www/keitaro:/var/www/keitaro \
                  "${CERTBOT_IMAGE}" \
                  "${@}"
  
}

kctl_run_usage(){
  echo "Usage:"
  echo "  kctl run clickhouse-client                  start clickhouse shell"
  echo "  kctl run clickhouse-query                   execute clickhouse query"
  echo "  kctl run mysql-client                       start mysql shell"
  echo "  kctl run mysql-query                        execute mysql query"
  echo "  kctl run cli-php                            execute cli.php command"
  echo "  kctl run redis-client                       execute redis shell"
  echo "  kctl run nginx                              perform nginx command"
  echo "  kctl run certbot                            perform certbot command"
}

kctl_run_nginx() {
  if empty "${@}"; then
    echo "Thats wrong to run nginx commang without argumets"
  else
    kctl_run_nginx_in_docker "${@}"
  fi
}


kctl_run_nginx_in_docker() {
  docker exec -i --env HOME=/tmp nginx \
  nginx "${@}"
}

# shellcheck source=/dev/null

kctl_run_clickhouse_in_docker() {
  local docker_exec_args="${1}"; shift
  source /etc/keitaro/config/tracker.env

  docker exec --env HOME=/tmp "${docker_exec_args}" clickhouse \
         clickhouse-client --host "${CH_HOST}" --port="${CH_PORT}" \
                           --user="${CH_USER}" --password="${CH_PASSWORD}"  \
                           --database="${CH_DB}" \
                           "${@}"
}

kctl_run_clickhouse_client() {
  kctl_run_clickhouse_in_docker "-it"
}

kctl_run_clickhouse_query() {
  local sql="${1}"
  if [[ "${sql}" == "" ]]; then
    kctl_run_clickhouse_in_docker "-i" --format=TabSeparated
  else
    kctl_run_clickhouse_in_docker "-i" --format=TabSeparated --query="${sql}"
  fi
}
# shellcheck source=/dev/null

kctl_run_mysql_in_docker() {
  local docker_exec_args="${1}"; shift
  source /etc/keitaro/config/tracker.env
  docker exec --env HOME=/tmp "${docker_exec_args}" mariadb \
         mysql --host "${MARIADB_HOST}" --port="${MARIADB_PORT}" \
               --user="${MARIADB_USERNAME}" --password="${MARIADB_PASSWORD}"  \
               --database="${MARIADB_DB}" \
               "${@}"
}

kctl_run_mysql_client() {
  kctl_run_mysql_in_docker "-it"
}

kctl_run_mysql_query() {
  local sql="${1}"
  if [[ "${sql}" == "" ]]; then
    kctl_run_mysql_in_docker "-i" --raw --batch --skip-column-names --default-character-set=utf8
  else
    kctl_run_mysql_in_docker "-i" --raw --batch --skip-column-names --default-character-set=utf8 --execute="${sql}"
  fi
}

kctl_run_cli_php() {
  sudo -u keitaro /usr/bin/kctl-php /var/www/keitaro/bin/cli.php "${@}"
}

kctl_features_usage() {
  echo "Usage:"
  echo "  kctl features enable <feature>                  enable feature"
  echo "  kctl features disable <feature>                 disable feature"
  echo "  kctl features list                              list supported features"
  echo
  echo "Supported features: ${SUPPORTED_FEATURES[*]}"
  echo
}

kctl_features_enable() {
  local feature="${1}"
  if empty "${feature}"; then
    kctl_features_usage
  else
    if arrays.in "${feature}" "${SUPPORTED_FEATURES[@]}"; then
      kctl_features_enable_feature "${feature}"

      if [[ "${feature}" == "${FEATURE_RBOOSTER}" ]]; then
        kctl_features_enable_rbooster
      else
        kctl_features_tune_tracker
      fi
    else
      kctl_features_usage
    fi
  fi
}

kctl_features_enable_feature() {
  local feature="${1}"
  load_features
  if ! arrays.in "${feature}" "${ENABLED_FEATURES[@]}"; then
    # shellcheck disable=SC2207
    ENABLED_FEATURES=($(arrays.add "${feature}" "${ENABLED_FEATURES[@]}"))
    save_features
  fi
}

run_ch_migrator(){
  local command
  command="kctl-ch-migrator --prefix=$(get_tracker_config_value 'db' 'prefix') \
    --env-file-path=${INVENTORY_DIR}/tracker.env"
  run_command "${command}"
}

kctl_features_enable_rbooster() {
  set_olap_db "${OLAP_DB_CLICKHOUSE}"
  run_ch_migrator
}

set_olap_db() {
  local olap_db="${1}"
  local log_path="${KCTL_LOG_DIR}/kctl-set-olap-db-to-${olap_db}.log"
  local roles_to_replay="install-clickhouse,install-mariadb,tune-tracker"

  assert_tracker_supports_rbooster

  debug "Running command \`KCTL_OLAP_DB='${olap_db}' kctl-install -U -o '${log_path}' -t '${roles_to_replay}'\`"
  KCTL_OLAP_DB="${olap_db}" kctl-install -U -o "${log_path}" -t "${roles_to_replay}"
}

assert_tracker_supports_rbooster() {
  if ! tracker_supports_rbooster; then
    fail "$(translate "errors.tracker_doesnt_support_feature" \
                      'feature=rbooster' \
                      "current_tracker_version=$(get_tracker_version)" \
                      "featured_tracker_version=${TRACKER_SUPPORTS_RBOOSTER_SINCE}")"
  fi
}

kctl_features_disable_rbooster() {
  set_olap_db "${OLAP_DB_MARIADB}"
}

kctl_features_list(){
  echo "Feature list:"
  echo " rbooster               Use ClickHouse as OLAP DB"
}

kctl_features_disable() {
  local feature="${1}"
  if empty "${feature}"; then
    kctl_features_usage
  else
    if arrays.in "${feature}" "${SUPPORTED_FEATURES[@]}"; then
      kctl_features_disable_feature "${feature}"

      if [[ "${feature}" == "${FEATURE_RBOOSTER}" ]]; then
        kctl_features_disable_rbooster
      else
        kctl_features_tune_tracker
      fi
    else
      kctl_features_usage
    fi
  fi
}

kctl_features_disable_feature() {
  local feature="${1}"
  load_features
  if arrays.in "${feature}" "${ENABLED_FEATURES[@]}"; then
    # shellcheck disable=SC2207
    ENABLED_FEATURES=($(arrays.remove "${feature}" "${ENABLED_FEATURES[@]}"))
    save_features
  fi
}

kctl_resolvers_reset() {
  local resolvers_entry="nameserver ${DNS_GOOGLE}"
  if file_content_matches "${RESOLV_CONF}" '-F' "${resolvers_entry}"; then
    other_ipv4_entries=$(grep "^nameserver" "${RESOLV_CONF}" | grep -vF "${resolvers_entry}" | grep '\.')
    debug "Other ipv4 entries: ${other_ipv4_entries}"
    if isset "${other_ipv4_entries}"; then
      debug "${RESOLV_CONF} contains 'nameserver ${DNS_GOOGLE}', deleting"
      run_command "sed -r -i '/^nameserver ${DNS_GOOGLE}$/d' '${RESOLV_CONF}'"
    else
      debug "${RESOLV_CONF} contains only one ipv4 nameserver keeping"
    fi
  else
    debug "${RESOLV_CONF} doesn't contain 'nameserver ${DNS_GOOGLE}', skipping"
  fi
}

kctl_resolvers_set_google() {
  if file_content_matches "${RESOLV_CONF}" '-F' "nameserver ${DNS_GOOGLE}"; then
    debug "${RESOLV_CONF} already contains 'nameserver ${DNS_GOOGLE}', skipping"
  else
    debug "${RESOLV_CONF} doesn't contain 'nameserver ${DNS_GOOGLE}', adding"
    run_command "sed -i '1inameserver ${DNS_GOOGLE}' ${RESOLV_CONF}"
  fi
}

kctl_resolvers_usage() {
  echo "Usage:"
  echo "  kctl resolvers set-google                        sets google dns"
  echo "  kctl resolvers reset                             resets settings"
  echo "  kctl resolvers usage                             prints this page"
}

ENABLED_FEATURES=()
FEATURES_DELIMITER=','
FEATURE_RBOOSTER='rbooster'
SUPPORTED_FEATURES=(
  "${FEATURE_RBOOSTER}"
)

kctl_features() {
  local action="${1}"
  local feature="${2}"
  case "${action}" in
    enable)
      kctl_features_enable "${feature}"
      ;;
    disable)
      kctl_features_disable "${feature}"
      ;;
    list)
      kctl_features_list
      ;;
    *)
      kctl_features_usage
  esac
}

arrays.in() {
  local value="${1}"; shift
  local array=("${@}")

  [[ "$(arrays.index_of "${value}" "${array[@]}")" != "" ]]
}

arrays.index_of() {
  local value="${1}"; shift
  local array=("${@}")

  for ((index=0; index<${#array[@]}; index++)); do
    if [[ "${array[$index]}" == "${value}" ]]; then
      echo "${index}"
      break
    fi
  done
}

arrays.add() {
  local value="${1}"; shift
  local array=("${@}")

  array+=("${value}")

  echo "${array[@]}"
}

arrays.remove() {
  local value="${1}"; shift
  local array=("${@}")

  value_index="$(arrays.index_of "${value}" "${array[@]}")"

  if [[ "${value_index}" != "" ]]; then
    unset 'array[value_index]'
  fi

  echo "${array[@]}"
}

load_features() {
  # shellcheck source=/dev/null
  source "${PATH_TO_TRACKER_ENV}"
  IFS="${FEATURES_DELIMITER}" read -r -a ENABLED_FEATURES <<< "${FEATURES:-}"
}

save_features() {
  local enabled_features_str="${ENABLED_FEATURES[*]}"
  debug "enabled_features_str: ${enabled_features_str}"
  local line_to_save="FEATURES=${enabled_features_str// /${FEATURES_DELIMITER}}"
  debug "line_to_save: ${line_to_save}"
  if file_content_matches "${PATH_TO_TRACKER_ENV}" '-P' "^FEATURES="; then
    sed -i "s/^FEATURES=.*/${line_to_save}/g" "${PATH_TO_TRACKER_ENV}"
  else
    echo "${line_to_save}" >> "${PATH_TO_TRACKER_ENV}"
  fi
  debug "FEATURES env is set to '${line_to_save}' in ${PATH_TO_TRACKER_ENV}"
}

kctl_features_tune_tracker() {
  debug "Running command \`KCTL_OLAP_DB='${olap_db}' kctl-install -U -t 'tune-tracker'\`"
  kctl-install -U -t 'tune-tracker'
}

reset_mysql_password(){
  local user="${1}" new_password sql

  new_password=$(generate_password)
  sql="UPDATE mysql.user SET password=PASSWORD('${new_password}') WHERE user='${user}'; FLUSH PRIVILEGES;"

  mysql  --defaults-file=/root/.my.cnf -Nse "${sql}"

  if [ "${user}" == "root" ]; then
    sed -i -e "s/^password=.*/password=${new_password}/g" /root/.my.cnf
  elif [ "${user}" == "keitaro" ]; then
    sed -i -e "s/^MARIADB_PASSWORD=.*/MARIADB_PASSWORD=${new_password}/g" /etc/keitaro/config/tracker.env
  fi
}

reset_tracker_salt() {
  local new_salt
  new_salt="$(generate_uuid)"
  sed -i -e "s/^SALT=.*/SALT=${new_salt}/g" /etc/keitaro/config/tracker.env
}
# shellcheck source=/dev/null

reset_machine_id() {
  generate_uuid > /etc/machine-id
  source /etc/keitaro/config/kctl-monitor.env
  kctl-monitor -r > /dev/null
}

reset_license_ip() {
  detect_server_ip
  sed -i -e "s/^LICENSE_IP=.*/LICENSE_IP=${SERVER_IP}/g" /etc/keitaro/config/tracker.env
}

reset_ch_password(){
  local new_password
  local new_hashed_password
  local old_hashed_password

  old_hashed_password="$(grep  -oP '(?<=<password_sha256_hex>).*?(?=</password_sha256_hex>)' /etc/clickhouse/users.xml)"
  new_password="$(generate_password)"
  new_hashed_password=$(echo -n "${new_password}" | sha256sum -b | awk '{print$1}')

  sed -i "s/${old_hashed_password}/${new_hashed_password}/g" /etc/clickhouse/users.xml
  sed -i -e "s/^CH_PASSWORD=.*/CH_PASSWORD=${new_password}/g" /etc/keitaro/config/tracker.env
  sed -i -e "s/^ch_password=.*/ch_password=${new_password}/g" /etc/keitaro/config/inventory
  systemctl restart clickhouse
}
# shellcheck source=/dev/null

kctl_run_redis_in_docker() {
  local docker_exec_args="${1}"; shift
  source /etc/keitaro/config/tracker.env
  docker exec --env HOME=/tmp "${docker_exec_args}" redis \
         redis-cli  "${@}"
}

kctl_run_redis_client() {
  kctl_run_redis_in_docker "-it" "${@}"
}
declare -A DICT
DICT['en.messages.sleeping_before_next_try']="Error while install, sleeping for :retry_interval: seconds before next try"
DICT['en.messages.kctl_version']="Kctl:    :kctl_version:"
DICT['en.messages.kctl_tracker']="Tracker: :tracker_version:"
DICT['en.errors.tracker_version_to_install_is_empty']='Tracker version is not specified'
DICT['en.errors.tracker_version_to_install_is_incorrect']="Tracker version can't be less than ${MIN_TRACKER_VERSION_TO_INSTALL}"
DICT['en.errors.invalid_options']="Invalid option ${1}. Try 'kctl help' for more information."
DICT['en.errors.tracker_doesnt_support_feature']="Current tracker v:current_tracker_version: doesn't support :feature:. Please upgrade tracker to v:featured_tracker_version:+"
DICT['en.errors.tracker_is_not_installed']="Keitaro tracker is not installed"
CURRENT_DATETIME="$(date +%Y%m%d%H%M)"
MIN_TRACKER_VERSION_TO_INSTALL='9.13.0'
declare -a RETRY_INTERVALS=(60 180 300)

# Based on https://stackoverflow.com/a/53400482/612799
#
# Use:
#   (( $(as_version 1.2.3.4) >= $(as_version 1.2.3.3) )) && echo "yes" || echo "no"
#
# Version number should contain from 1 to 4 parts (3 dots) and each part should contain from 1 to 3 digits
#
AS_VERSION__MAX_DIGITS_PER_PART=3
AS_VERSION__PART_REGEX="[[:digit:]]{1,${AS_VERSION__MAX_DIGITS_PER_PART}}"
AS_VERSION__PARTS_TO_KEEP=4
AS_VERSION__REGEX="(${AS_VERSION__PART_REGEX}\.){1,${AS_VERSION__PARTS_TO_KEEP}}"

as_version() {
  local version_string="${1}"
  # Expand version string by adding `.` to the end to simplify logic
  local major_part='0'
  local minor_part='0'
  local patch_part='0'
  local additional_part='0'
  if [[ "${version_string}." =~ ^${AS_VERSION__REGEX}$ ]]; then
    IFS='.' read -r -a parts <<< "${version_string}"
    major_part="${parts[0]:-${major_part}}"
    minor_part="${parts[1]:-${minor_part}}"
    patch_part="${parts[2]:-${patch_part}}"
    additional_part="${parts[3]:-${additional_part}}"
  fi
  printf '1%03d%03d%03d%03d' "${major_part}" "${minor_part}" "${patch_part}" "${additional_part}"
}

as_minor_version() {
  local version_string="${1}"
  local version_number
  version_number=$(as_version "${version_string}")
  local meaningful_version_length=$(( 1 + 2*AS_VERSION__MAX_DIGITS_PER_PART ))
  local zeroes_length=$(( 1 + AS_VERSION__PARTS_TO_KEEP * AS_VERSION__MAX_DIGITS_PER_PART - meaningful_version_length ))
  local meaningful_version=${version_number:0:${meaningful_version_length}}
  printf "%d%0${zeroes_length}d" "${meaningful_version}"
}

detect_installed_version(){
  if empty "${INSTALLED_VERSION}"; then
    detect_inventory_path
    if isset "${DETECTED_INVENTORY_PATH}"; then
      INSTALLED_VERSION=$(grep "^installer_version=" "${DETECTED_INVENTORY_PATH}" | sed s/^installer_version=//g)
      debug "Got installer_version='${INSTALLED_VERSION}' from ${DETECTED_INVENTORY_PATH}"
    fi
    if empty "${INSTALLED_VERSION}"; then
      debug "Couldn't detect installer_version, resetting to ${VERY_FIRST_VERSION}"
      INSTALLED_VERSION="${VERY_FIRST_VERSION}"
    fi
  fi
}

get_tracker_config_value() {
  local section="${1}"
  local parameter="${2}"
  local expression="/^\[${section}\]/ { :l /^${parameter}\s*=/ { s/.*=\s*//; p; q;}; n; b l;}"
  if file_exists "${TRACKER_CONFIG_FILE}"; then
    sed -nr "${expression}" "${TRACKER_CONFIG_FILE}" | unquote
  fi
}

detect_inventory_path(){
  debug "Detecting inventory path"
  paths=("${INVENTORY_PATH}" /root/.keitaro/installer_config .keitaro/installer_config /root/hosts.txt hosts.txt)
  for path in "${paths[@]}"; do
    if [[ -f "${path}" ]]; then
      DETECTED_INVENTORY_PATH="${path}"
      debug "Inventory found - ${DETECTED_INVENTORY_PATH}"
      return
    fi
  done
  debug "Inventory file not found"
}

read_inventory(){
  detect_inventory_path
  if isset "${DETECTED_INVENTORY_PATH}"; then
    parse_inventory "${DETECTED_INVENTORY_PATH}"
  fi
}

parse_inventory() {
  local file="${1}"
  debug "Found inventory file ${file}, reading defaults from it"
  while IFS="" read -r line; do
    if [[ "$line" =~ = ]]; then
      parse_line_from_inventory_file "$line"
    fi
  done < "${file}"
}

parse_line_from_inventory_file(){
  local line="${1}"
  local quoted_string_regex="^'.*'\$"
  IFS="=" read -r var_name value <<< "$line"
  if [[ "$var_name" != "db_restore_path" ]]; then
    if [[ "${value}" =~ ${quoted_string_regex} ]]; then
      debug "# ${value} is quoted, removing quotes"
      value_without_quotes="${value:1:-1}"
      debug "# $var_name: quotes removed - ${value} -> ${value_without_quotes}"
      value="${value_without_quotes}"
    fi
    if empty "${VARS[$var_name]}"; then
      VARS[$var_name]=$value
      debug "# read '$var_name' from inventory"
    else
      debug "# $var_name is set from options, skip inventory value"
    fi
    debug "  $var_name=${VARS[$var_name]}"
  fi
}
MYIP_KEITARO_IO="https://myip.keitaro.io"

detect_server_ip() {
  debug "Detecting server IP address"
  debug "Getting url '${MYIP_KEITARO_IO}'"
  SERVER_IP="$(curl -fsSL4 ${MYIP_KEITARO_IO} 2>&1)"
  debug "Done, result is '${SERVER_IP}'"
}


unquote() {
  sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
}


generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}
generate_uuid() {
  uuidgen | tr -d '-'
}

init "${@}"

action="${1}"
shift || true

assert_caller_root

case "${action}" in
  install)
    kctl_auto_install "" "kctl-install.log"
    ;;
  upgrade)
    kctl_auto_install -U "kctl-upgrade.log"
    ;;
  tune)
    kctl_auto_install -U "kctl-tune.log" tune
    ;;
  rescue|doctor)
    kctl_auto_install -C "kctl-rescue.log"
    ;;
  downgrade)
    rollback_version="${1:-latest-stable}"
    kctl_install_tracker "${rollback_version}"
    ;;
  install-tracker)
    kctl_install_tracker "${@}"
    ;;
  certificates)
    kctl_certificates "${@}"
    ;;
  features)
    kctl_features "${@}"
    ;;
  podman)
    kctl_podman "${@}"
    ;;
  resolvers)
    kctl_resolvers "${@}"
    ;;
  run)
    kctl_run "${@}"
    ;;
  reset|password-change)
    kctl_reset
    ;;
  transfers|transfer)
    kctl-transfers "${@}"
    ;;
  help)
    kctl_show_help
    ;;
  version)
    kctl_show_version
    ;;
  "")
    kctl_show_version
    ;;
  *)
    fail "$(translate errors.invalid_options)"
esac
