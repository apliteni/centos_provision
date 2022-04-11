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


TOOL_NAME='install'

SELF_NAME=${0}


RELEASE_VERSION='2.34.3'
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

TOOL_ARGS="${*}"

DB_ENGINE_INNODB="innodb"
DB_ENGINE_TOKUDB="tokudb"
DB_ENGINE_DEFAULT="${DB_ENGINE_TOKUDB}"

PHP_ENGINE_ROADRUNNER="roadrunner"
PHP_ENGINE_DEFAULT="${PHP_ENGINE_ROADRUNNER}"

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
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You runs this program as root.'
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

assert_keitaro_not_installed(){
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
     file_exists "${KEITARO_LOCK_FILEPATH}"
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

assert_upgrade_allowed() {
  if is_keitaro_installed; then
    ensure_nginx_config_correct
    debug 'Everything looks good, running upgrade'
  else
    debug "Can't upgrade because installation process is not finished yet"
    fail "$(translate errors.cant_upgrade)"
  fi
}

ensure_nginx_config_correct() {
  run_command "nginx -t" "$(translate 'messages.validate_nginx_conf')" "hide_output"
}
detect_db_engine() {
  local sql="SELECT lower(engine) FROM information_schema.tables WHERE table_name = 'keitaro_clicks'"
  local db_engine
  db_engine="$(mysql "${VARS['db_name']}" -se "${sql}" 2>/dev/null)"
  debug "Detected engine from keitaro_clicks table - '${db_engine}'"
  echo "${db_engine}"
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

get_centos_major_release() {
  grep -oP '(?<=release )\d+' /etc/centos-release
}


is_compatible_with_current_release() {
  [[ "${RELEASE_VERSION}" == "${INSTALLED_VERSION}" ]]
}

run_obsolete_tool_version_if_need() {
  debug 'Ensure configs has been genereated by relevant installer'
  if isset "${FORCE_ISSUING_CERTS}"; then
    debug "Skip checking current version and force isuuing certs"
  elif is_compatible_with_current_release; then
    debug "Current ${RELEASE_VERSION} is compatible with ${INSTALLED_VERSION}"
  else
    local tool_url="${KEITARO_URL}/v${INSTALLED_VERSION}/${TOOL_NAME}.sh"
    local tool_args="${TOOL_ARGS}"
    if (( $(as_version "${INSTALLED_VERSION}") < $(as_version "1.13") )); then
      fail "$(translate 'errors.upgrade_server')"
    fi
    if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
      tool_args="-D ${VARS['ssl_domains']}"
    fi
    command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
    run_command "${command}" "Running obsolete ${TOOL_NAME} (v${INSTALLED_VERSION})"
    exit
  fi
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

install_package(){
  local package="${1}"
  if ! is_package_installed "${package}"; then
    debug "Installing ${package}"
    run_command "yum install -y ${package}"
  else
    debug "Package ${package} is already installed"
  fi
}

is_installed(){
  local command="${1}"
  debug "Try to find command '$command'"
  if [[ $(sh -c "command -v '$command' -gt /dev/null") ]]; then
    debug "FOUND: Command '$command' found"
  else
    debug "NOT FOUND: Command '$command' not found"
    return ${FAILURE_RESULT}
  fi
}

is_package_installed(){
  local package="${1}"
  debug "Try to find package '$package'"
  if yum list installed --quiet "$package" &> /dev/null; then
    debug "FOUND: Package '$package' found"
  else
    debug "NOT FOUND: Package '$package' not found"
    return ${FAILURE_RESULT}
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
  print_err "Try '${SCRIPT_NAME} -h' for more information."
  print_err
}

usage_en_header(){
  print_err "Usage: ${SCRIPT_NAME} [OPTION]..."
}

help_en_common(){
  print_err "Miscellaneous:"
  print_err "  -h                       display this help text and exit"
  print_err
  print_err "  -v                       display version information and exit"
  print_err
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

init_kctl() {
  init_kctl_dirs_and_links
  init_log "${LOG_PATH}"
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

start_or_reload_nginx(){
  if (file_exists "/run/nginx.pid" && [[ -s "/run/nginx.pid" ]]) || is_ci_mode; then
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

join_by(){
  local delimiter=$1
  shift
  echo -n "$1"
  shift
  printf "%s" "${@/#/${delimiter}}"
}

to_lower(){
  local string="${1}"
  echo "${string,,}"
}

unquote() {
  sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
}

#


FIRST_KEITARO_TABLE_NAME="acl"

detect_table_prefix(){
  local file="${1}"
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local mime_type
  mime_type="$(detect_mime_type "${file}")"
  debug "Detected mime type: ${mime_type}"
  local get_head_chunk
  get_head_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "head -n 100")"
  if empty "${get_head_chunk}"; then
    return ${FAILURE_RESULT}
  fi
  local command="${get_head_chunk}"
  command="${command} | grep -P $(build_check_table_exists_expression ".*${FIRST_KEITARO_TABLE_NAME}")"
  command="${command} | head -n 1"
  command="${command} | grep -oP '\`.*\`'"
  command="${command} | sed -e 's/\`//g' -e 's/${FIRST_KEITARO_TABLE_NAME}\$//'"
  command="(set +o pipefail && ${command})"
  message="$(translate 'messages.check_keitaro_dump_get_tables_prefix')"
  rm -f "${DETECTED_PREFIX_PATH}"
  if run_command "$command" "$message" 'hide_output' 'allow_errors' '' '' "$DETECTED_PREFIX_PATH" > /dev/stderr; then
    cat "$DETECTED_PREFIX_PATH" | head -n1
  fi
}


build_check_table_exists_expression() {
  local table="${1}"
  echo "'^CREATE TABLE( IF NOT EXISTS)? \`${table}\`'"
}


build_get_chunk_command() {
  local mime_type="${1}"
  local file="${2}"
  local filter="${3}"
  if [[ "$mime_type" == 'text/plain' ]]; then
    echo "${filter} '${file}'"
  fi
  if [[ "$mime_type" == 'application/x-gzip' ]]; then
    echo "zcat '${file}' | ${filter}"
  fi
}

ensure_valid() {
  local option="${1}"
  local var_name="${2}"
  local validation_methods="${3}"
  error="$(get_error "${var_name}" "${validation_methods}")"
  if isset "$error"; then
    print_err "-${option}: $(translate "validation_errors.${error}" "value=${VARS[$var_name]}")"
    exit "${FAILURE_RESULT}"
  fi
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


validate_absence(){
  local value="${1}"
  empty "$value"
}

validate_alnumdashdot(){
  local value="${1}"
  [[ "$value" =~  ^([0-9A-Za-z_\.\-]+)$ ]]
}

validate_directory_existence(){
  local value="${1}"
  [[ -d "$value" ]]
}
SUBDOMAIN_REGEXP="[[:alnum:]-]+"
DOMAIN_REGEXP="(${SUBDOMAIN_REGEXP}\.)+[[:alpha:]]${SUBDOMAIN_REGEXP}"
MAX_DOMAIN_LENGTH=64
DOMAIN_LENGTH_REGEXP="[^,]{1,${MAX_DOMAIN_LENGTH}}"

validate_domain(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_REGEXP}$ ]] && [[ "$value" =~ ^${DOMAIN_LENGTH_REGEXP}$ ]]
}
DOMAIN_LIST_REGEXP="${DOMAIN_REGEXP}(,${DOMAIN_REGEXP})*"
DOMAIN_LIST_LENGTH_REGEXP="${DOMAIN_LENGTH_REGEXP}(,${DOMAIN_LENGTH_REGEXP})*"


validate_domains_list(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_LIST_REGEXP}$ ]] && [[ "${value}" =~ ^${DOMAIN_LIST_LENGTH_REGEXP}$ ]]
}

validate_enough_space_for_dump() {
  local file="${1}"
  local dump_size_in_kb
  local needed_space_in_kb
  local available_space_in_mb
  local available_space_in_kb
  local unpacked_dump_size_in_kb

  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  dump_size_in_kb=$(du -k "$file" | cut -f1)
  available_space_in_mb=$(get_free_disk_space_mb)
  available_space_in_kb=$((available_space_in_mb * 1024))

  if file --mime-type "$file" | grep -q gzip$; then
    unpacked_dump_size_in_kb=$((dump_size_in_kb * 7))
    needed_space_in_kb=$((unpacked_dump_size_in_kb * 25 / 10))
  else
    needed_space_in_kb=$((dump_size_in_kb * 15 / 10))
  fi

  if [[ "$needed_space_in_kb" -gt "$available_space_in_kb" ]]; then
    return ${FAILURE_RESULT}
  else
    return ${SUCCESS_RESULT}
  fi
}
#





validate_file_existence(){
  local value="${1}"
  if empty "$value"; then
    return ${SUCCESS_RESULT}
  fi
  [[ -f "$value" ]]
}

validate_not_reserved_word(){
  local value="${1}"
  [[ "$value" !=  'yes' ]] && [[ "$value" != 'no' ]] && [[ "$value" != 'true' ]] && [[ "$value" != 'false' ]]
}

validate_not_root(){
  local value="${1}"
  [[ "$value" !=  'root' ]]
}


validate_presence(){
  local value="${1}"
  isset "$value"
}

validate_starts_with_latin_letter(){
  local value="${1}"
  [[ "$value" =~  ^[A-Za-z] ]]
}

is_no(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(no|n|нет|н)$ ]]
}

is_yes(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(yes|y|да|д)$ ]]
}

transform_to_yes_no(){
  local var_name="${1}"
  if is_yes "${VARS[$var_name]}"; then
    debug "Transform ${var_name}: ${VARS[$var_name]} => yes"
    VARS[$var_name]='yes'
  else
    debug "Transform ${var_name}: ${VARS[$var_name]} => no"
    VARS[$var_name]='no'
  fi
}
validate_yes_no(){
  local value="${1}"
  (is_yes "$value" || is_no "$value")
}


PROVISION_DIRECTORY="centos_provision"
PROVISION_BIN_DIRECTORY="../bin"
PLAYBOOK_DIRECTORY="${PROVISION_DIRECTORY}/playbook"
KEITARO_ALREADY_INSTALLED_RESULT=0
DETECTED_PREFIX_PATH="${WORKING_DIR}/detected_prefix"

SERVER_IP=""

INSTALLED_VERSION=""

DICT['en.messages.keitaro_already_installed']='Keitaro is already installed'
DICT['en.messages.check_keitaro_dump_get_tables_prefix']="Getting tables prefix from dump"
DICT['en.messages.check_keitaro_dump_validity']="Checking SQL dump"
DICT['en.messages.validate_nginx_conf']='Checking nginx config'
DICT['en.messages.successful.use_old_credentials']="The database was successfully restored from the archive. Use old login data"
DICT['en.messages.successful_install']='Keitaro is installed!'
DICT['en.messages.successful_upgrade']='Keitaro is upgraded!'
DICT['en.messages.successful_restore']="Keitaro is restored! Use old login data"
DICT['en.messages.visit_url']="Please open the link in your browser of choice:"
DICT['en.errors.wrong_distro']='The installer is not compatible with this operational system. Please reinstall this server with "CentOS 8 Stream" or "CentOS 7"'
DICT['en.errors.not_enough_ram']='The size of RAM on your server should be at least 2 GB'
DICT['en.errors.not_enough_free_disk_space']='The free disk space on your server must be at least 2 GB.'
DICT['en.errors.keitaro_dump_invalid']='SQL dump is broken'
DICT['en.errors.isp_manager_installed']='You can not install Keitaro on the server with ISP Manager installed. Please run this program on a clean CentOS server.'
DICT['en.errors.vesta_cp_installed']='You can not install Keitaro on the server with Vesta CP installed. Please run this program on a clean CentOS server.'
DICT['en.errors.apache_installed']='You can not install Keitaro on the server with Apache HTTP server installed. Please run this program on a clean CentOS server.'
DICT['en.errors.systemctl_doesnt_work_properly']="You can not install Keitaro on the server where systemctl doesn't work properly. Please run this program on another CentOS server."
DICT['en.errors.cant_detect_server_ip']="The installer couldn't detect the server IP address, please contact Keitaro support team"
DICT['en.errors.cant_detect_table_prefix']="The installer couldn't detect dump table prefix"
DICT['en.errors.already_running']="Another installation process is already running"

DICT['en.prompts.db_restore_path']='Please enter the path to the SQL dump file'
DICT['en.prompts.salt']='Please enter "salt" parameter (see old application/config/config.ini.php)'
DICT['en.welcome']='This installer will guide you through the steps required to install Keitaro on your server.'
DICT['en.validation_errors.validate_alnumdashdot']='Only Latin letters, numbers, dashes, underscores and dots allowed'
DICT['en.validation_errors.validate_file_existence']='The file was not found by the specified path, please enter the correct path to the file'
DICT['en.validation_errors.validate_enough_space_for_dump']='Dont enough space for restore dump'
DICT['en.validation_errors.validate_not_reserved_word']='You are not allowed to use yes/no/true/false as value'
DICT['en.validation_errors.validate_starts_with_latin_letter']='The value must begin with a Latin letter'


get_ansible_galaxy_command() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "ansible-galaxy-3"
  else
    echo "ansible-galaxy"
  fi
}
install_ansible_collection(){
  local collection="${1}"
  local package="${collection//\./-}.tar.gz"
  local collection_url="${FILES_KEITARO_ROOT_URL}/scripts/ansible-galaxy-collections/${package}"
  ansible_galaxy_command="$(get_ansible_galaxy_command)"
  debug "Installing ansible collection ${collection} from ${collection_url}"
  run_command "${ansible_galaxy_command} collection install ${collection_url} --force"
}

get_ansible_package_name() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "ansible-python3"
  elif [[ "$(get_centos_major_release)" == "9" ]]; then
    echo "ansible-core"
  else
    echo "ansible"
  fi
}

get_config_value(){
  local var="${1}"
  local file="${2}"
  local separator="${3}"
  if file_exists "${file}"; then
    grep "^${var}\\b" "${file}" | \
      grep "${separator}" | \
      head -n1 | \
      awk -F"${separator}" '{print $2}' | \
      awk '{$1=$1; print}' | \
      unquote
  fi
}

get_ram_size_mb() {
  (free -m | grep Mem: | awk '{print $2}') 2>/dev/null
}

clean_up(){
  if [ -d "$PROVISION_DIRECTORY" ]; then
    debug "Remove ${PROVISION_DIRECTORY}"
    rm -rf "$PROVISION_DIRECTORY"
  fi
}

# If installed version less than or equal to version from array value
# then ANSIBLE_TAGS will be expanded by appropriate tags (given from array key)
# Example:
#   when REPLAY_ROLE_TAGS_ON_UPGRADE_FROM=( ['init']='1.0' ['enable-swap']='2.0' )
#     and insalled version is 2.0
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `enable-swap` tag
declare -A REPLAY_ROLE_TAGS_SINCE=(
  ['init-tracker-user-and-dirs']='2.30.10'
  ['install-chrony']='2.27.7'
  ['install-docker']='2.29.4'
  ['install-fail2ban']='2.32.3'
  ['install-firewalld']='2.29.15'
  ['install-htop-config']='2.32.3'
  ['install-packages']='2.27.7'
  ['install-postfix']='2.29.8'
  ['remove-x3-ca']='2.32.3'
  ['setup-journald']='2.32.0'
  ['setup-selinux']='2.25.0'
  ['setup-thp']='0.9'
  ['setup-timezone']='0.9'
  ['tune-swap']='2.27.7'
  ['tune-sysctl']='2.27.7'

  ['install-clickhouse']='2.33.3'
  ['tune-clickhouse']='2.33.3'

  ['install-mariadb']='2.32.3'
  ['tune-mariadb']='2.33.3'

  ['tune-nginx']='2.32.2'

  ['install-php']='2.30.10'
  ['install-roadrunner']='2.20.4'
  ['tune-php']='2.34.0'
  ['tune-roadrunner']='2.34.0'

  ['tune-redis']='2.27.7'

  ['tune-tracker']='2.30.10'
  ['upgrade-tracker']='2.30.10'
  ['wrap-up-tracker-configuration']='2.30.10'
)

expand_ansible_tags_on_upgrade() {
  if [[ "${RUNNING_MODE}" != "${RUNNING_MODE_UPGRADE}" ]] ; then
    return
  fi
  debug "Upgrade mode detected, expading ansible tags."
  local installed_version
  installed_version=$(get_installed_version_on_upgrade)
  debug "Upgrading ${installed_version} -> ${RELEASE_VERSION}"
  expand_ansible_tags_with_upgrade_tag
  expand_ansible_tags_with_tune_tag_on_changing_ram_size
  expand_ansible_tags_with_role_tags "${installed_version}"
  expand_ansible_tags_with_install_kctl_tools_tag "${installed_version}"
  debug "ANSIBLE_TAGS is set to ${ANSIBLE_TAGS}"
}

expand_ansible_tags_with_upgrade_tag() {
  expand_ansible_tags_with_tag "upgrade"
  if is_upgrading_mode_full; then
    expand_ansible_tags_with_tag "full-upgrade"
  fi
}

expand_ansible_tags_with_tune_tag_on_changing_ram_size() {
  if isset "${VARS['ram_size_mb_changed']}"; then
    debug 'RAM size was changed recently, force tuning'
    expand_ansible_tags_with_tag "tune"
  else
    debug 'RAM size is not changed recently'
  fi
}

expand_ansible_tags_with_role_tags() {
  local installed_version=${1}
  for role_tag in "${!REPLAY_ROLE_TAGS_SINCE[@]}"; do
    replay_role_tag_since=${REPLAY_ROLE_TAGS_SINCE[${role_tag}]}
    if (( $(as_version "${installed_version}") <= $(as_version "${replay_role_tag_since}") )); then
      expand_ansible_tags_with_tag "${role_tag}"
    fi
  done
}

expand_ansible_tags_with_install_kctl_tools_tag() {
  local installed_version=${1}
  if (( $(as_version "${installed_version}") < $(as_version "${RELEASE_VERSION}") )); then
    expand_ansible_tags_with_tag "install-kctl-tools"
  fi
}

get_installed_version_on_upgrade() {
  if is_upgrading_mode_full; then
    debug "Upgrading mode is 'full', simulating upgrade from ${VERY_FIRST_VERSION}"
    echo ${VERY_FIRST_VERSION}
  else
    echo "${INSTALLED_VERSION}"
  fi
}

is_upgrading_mode_full() {
  [[ "${UPGRADING_MODE}" == "${UPGRADING_MODE_FULL}" ]]
}

is_running_in_interactive_restoring_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_RESTORE}" ]] && \
    [[ "${RESTORING_MODE}" == "${RESTORING_MODE_INTERACTIVE}" ]]
}

is_running_in_upgrade_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_UPGRADE}" ]]
}

is_running_in_install_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_INSTALL}" ]]
}

get_free_disk_space_mb() {
  (df -m --output=avail / | tail -n1) 2>/dev/null
}


RUNNING_MODE_INSTALL="install"
RUNNING_MODE_UPGRADE="upgrade"
RUNNING_MODE_RESTORE="restore"
RUNNING_MODE="${RUNNING_MODE_INSTALL}"

RESTORING_MODE_INTERACTIVE="interactive"
RESTORING_MODE_NONINTERACTIVE="noninteractive"
RESTORING_MODE="${RESTORING_MODE_INTERACTIVE}"

UPGRADING_MODE_SMART="smart"
UPGRADING_MODE_FULL="full"
UPGRADING_MODE="${UPGRADING_MODE_SMART}"

parse_options(){
  while getopts ":RCUF:S:a:t:i:wo:L:WrK:A:k:l:hvs" option; do
    argument="${OPTARG}"
    ARGS["${option}"]="${argument}"
    case $option in
      R)
        RUNNING_MODE="${RUNNING_MODE_RESTORE}"
        ;;
      C)
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        UPGRADING_MODE="${UPGRADING_MODE_FULL}"
        ;;
      U)
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        ;;
      F)
        VARS['db_restore_path']="${argument}"
        ;;
      S)
        VARS['salt']="${argument}"
        ;;
      a)
        KCTL_TRACKER_VERSION_TO_INSTALL="${argument}"
        ;;
      t)
        ANSIBLE_TAGS="${argument}"
        ;;
      i)
        ANSIBLE_IGNORE_TAGS="${argument}"
        ;;
      w)
        WITHOUTH_YUM_UPDATE="true"
        ;;
      o)
        LOG_PATH="${argument}"
        ;;
      L)
        set_tracker_language "${argument}"
        ;;
      W)
        print_deprecation_warning '-W option will be removed soon, you can safely omit it'
        RUNNING_MODE="${RUNNING_MODE_INSTALL}"
        ;;
      r)
        print_deprecation_warning '-r option will be removed soon, use -U instead'
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        if [[ "${ANSIBLE_TAGS}" =~ full-upgrade ]]; then
          UPGRADING_MODE="${UPGRADING_MODE_FULL}"
        fi
        ;;
      K)
        print_deprecation_warning '-K option is deprecated'
        VARS['license_key']="${argument}"
        ;;
      A)
        print_deprecation_warning '-A option is ignored'
        ;;
      k)
        print_deprecation_warning '-k option is ignored'
        ;;
      l)
        print_deprecation_warning '-l option is deprecates use -L instead'
        set_tracker_language "${argument}"
        ;;
      s)
        SKIP_CENTOS_RELEASE_CHECK="true"
        ;;
      *)
        common_parse_options "$option" "${argument}"
        ;;
    esac
  done
  if isset "${ARGS['F']}" || isset "${ARGS['S']}"; then
    RUNNING_MODE="${RUNNING_MODE_RESTORE}"
    RESTORING_MODE="${RESTORING_MODE_NONINTERACTIVE}"
    ensure_valid F db_restore_path "validate_presence validate_file_existence validate_enough_space_for_dump"
    ensure_valid S salt "validate_presence validate_alnumdashdot"
  fi
  if [[ "${RUNNING_MODE}" == "${RUNNING_MODE_UPGRADE}" ]] && isset "${KCTL_TRACKER_VERSION_TO_INSTALL}"; then
    expand_ansible_tags_with_tag "upgrade-tracker"
    expand_ansible_tags_with_tag "tune-tracker"
  fi

  ensure_options_correct
}

set_tracker_language() {
  local language="${1}"

  if [[ "${language}" == 'ru' ]]; then
    VARS['tracker_language']='ru'
  else
    VARS['tracker_language']='en'
  fi
}


help_en(){
  print_err "${SCRIPT_NAME} installs and configures Keitaro"
  print_err "Example: ${SCRIPT_NAME}"
  print_err
  print_err "Automation:"
  print_err "  -U                       upgrade the system configuration and tracker"
  print_err
  print_err "  -C                       rescue the system configuration and tracker"
  print_err
  print_err "  -R                       restore tracker using dump"
  print_err
  print_err "  -F DUMP_FILEPATH         set filepath to dump (-S and -R should be specified)"
  print_err
  print_err "  -S SALT                  set salt for dump restoring (-F and -R should be specified)"
  print_err
  print_err "Customization:"
  print_err "  -a PATH_TO_PACKAGE       set path to Keitaro installation package"
  print_err
  print_err "  -t TAGS                  set ansible-playbook tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -i TAGS                  set ansible-playbook ignore tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -o output                sset the full path of the installer log output"
  print_err
  print_err "  -w                       do not run 'yum upgrade'"
  print_err
}
MYIP_KEITARO_IO="https://myip.keitaro.io"

detect_server_ip() {
  debug "Detecting server IP address"
  debug "Getting url '${MYIP_KEITARO_IO}'"
  SERVER_IP="$(curl -fsSL4 ${MYIP_KEITARO_IO} 2>&1)"
  debug "Done, result is '${SERVER_IP}'"
}


stage1() {
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  detect_server_ip
  debug "Running in mode '${RUNNING_MODE}'"
}


assert_not_running_under_openvz() {
  debug "Assert we are not running under OpenVZ"

  virtualization_type="$(hostnamectl status | grep Virtualization | awk '{print $2}')"
  debug "Detected virtualization type: '${virtualization_type}'"
  if isset "${virtualization_type}" && [[ "${virtualization_type}" == "openvz" ]]; then
    fail "Servers with OpenVZ virtualization are not supported"
  fi
}

assert_systemctl_works_properly () {
  if ! run_command "systemctl > /dev/null" "Checking systemd" 'hide_output' 'allow_errors'; then
    fail "$(translate errors.systemctl_doesnt_work_properly)"
  fi
}
MIN_RAM_SIZE_MB=1500

assert_has_enough_ram(){
  debug "Checking RAM size"

  local current_ram_size_mb
  current_ram_size_mb=$(get_ram_size_mb)
  if [[ "$current_ram_size_mb" -lt "$MIN_RAM_SIZE_MB" ]]; then
    debug "RAM size ${current_ram_size_mb}mb is less than ${MIN_RAM_SIZE_MB}mb, raising error"
    fail "$(translate errors.not_enough_ram)"
  else
    debug "RAM size ${current_ram_size_mb}mb is greater than ${MIN_RAM_SIZE_MB}mb, continuing"
  fi
}
MIN_FREE_DISK_SPACE_MB=2048

assert_has_enough_free_disk_space(){
  debug "Checking free disk spice"

  local current_free_disk_space_mb
  current_free_disk_space_mb=$(get_free_disk_space_mb)
  if [[ "${current_free_disk_space_mb}" -lt "${MIN_FREE_DISK_SPACE_MB}" ]]; then
    debug "Free disk space ${current_free_disk_space_mb}mb is less than ${MIN_FREE_DISK_SPACE_MB}mb, raising error"
    fail "$(translate errors.not_enough_free_disk_space)"
  else
    debug "Free disk space ${current_free_disk_space_mb}mb is greater than ${MIN_FREE_DISK_SPACE_MB}mb, continuing"
  fi
}


assert_thp_deactivatable() {
  debug "Checking if it is possible to disable THP"
  if is_ci_mode; then
    debug "Skip actual checking"
    return
  fi
  if are_thp_sys_files_existing; then
    debug "There are THP files in /sys fs, checking for ability to disable THP" 
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
    if [ "$thp_enabled" == "always madvise [never]" ]; then
      debug "OK, THP was successfully disabled"
    else
      fail "Can't disable Transparent Huge Pages" 
    fi
  else
    debug "There are no THP files in /sys fs, continuing installation process" 
  fi
}

are_thp_sys_files_existing() {
  file_exists "/sys/kernel/mm/transparent_hugepage/enabled" && file_exists "/sys/kernel/mm/transparent_hugepage/defrag"
}

assert_pannels_not_installed(){
  if is_installed mysql; then
    assert_isp_manager_not_installed
    assert_vesta_cp_not_installed
  fi
}


assert_isp_manager_not_installed(){
  if database_exists roundcube; then
    debug "ISP Manager database detected"
    fail "$(translate errors.isp_manager_installed)"
  fi
}


assert_vesta_cp_not_installed(){
  if database_exists admin_default; then
    debug "Vesta CP database detected"
    fail "$(translate errors.vesta_cp_installed)"
  fi
}


database_exists(){
  local database="${1}"
  debug "Check if database ${database} exists"
  mysql -Nse 'show databases' 2>/dev/null | tr '\n' ' ' | grep -Pq "${database}"
}

assert_running_on_supported_centos(){
  assert_installed 'yum' 'errors.wrong_distro'
  if ! file_exists /etc/centos-release; then
    fail "$(translate errors.wrong_distro)"
  fi
  if empty "${SKIP_CENTOS_RELEASE_CHECK}"; then
    assert_centos_release_is_supportded
  fi
}

assert_centos_release_is_supportded(){
  if ! file_content_matches /etc/centos-release '-P' '^CentOS .* (7|8|9)\b'; then
    fail "$(translate errors.wrong_distro)"
  fi
}

assert_apache_not_installed(){
  if is_installed httpd; then
    fail "$(translate errors.apache_installed)"
  fi
}

assert_server_ip_is_valid() {
  if ! valid_ip "${SERVER_IP}"; then
    fail "$(translate 'errors.cant_detect_server_ip')"
  fi
}

valid_ip(){
  local value="${1}"
  [[ "$value" =~  ^[[:digit:]]+(\.[[:digit:]]+){3}$ ]] && valid_ip_segments "$value"
}


valid_ip_segments(){
  local ip="${1}"
  local segments
  IFS='.' read -r -a segments <<< "${ip}"
  for segment in "${segments[@]}"; do
    if ! valid_ip_segment "${segment}"; then
      return "${FAILURE_RESULT}"
    fi
  done
}

valid_ip_segment(){
  local ip_segment="${1}"
  [ "$ip_segment" -ge 0 ] && [ "$ip_segment" -le 255 ]
}

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_no_another_process_running
  assert_caller_root
  assert_apache_not_installed
  assert_running_on_supported_centos
  assert_has_enough_ram
  assert_has_enough_free_disk_space
  assert_not_running_under_openvz
  assert_pannels_not_installed
  assert_thp_deactivatable
  assert_systemctl_works_properly
  assert_server_ip_is_valid
}

setup_vars() {
  detect_installed_version
  setup_default_value installer_version "${INSTALLED_VERSION}" "${RELEASE_VERSION}"
  setup_default_value db_name 'keitaro'
  setup_default_value ch_password "$(generate_password)"
  if ! file_exists "${INVENTORY_DIR}/tracker.env"; then
    setup_default_value salt "$(detect_salt)" "$(generate_salt)"
    setup_default_value db_user "$(get_tracker_config_value 'db' 'user')" 'keitaro'
    setup_default_value db_password "$(get_tracker_config_value 'db' 'password')" "$(generate_password)"
    setup_default_value db_root_password "$(get_config_value password "/root/my.cnf" '=')"  "$(generate_password)"
  fi
  VARS['php_engine']="${PHP_ENGINE_DEFAULT}"
  VARS['db_engine']="${DB_ENGINE_DEFAULT}"
}

detect_salt() {
  get_config_value "salt" "${TRACKER_CONFIG_FILE}" '='
}

setup_default_value() {
  local var_name="${1}"
  local default_value="${2:-${3}}"
  if empty "${VARS[${var_name}]}"; then
    debug "VARS['${var_name}'] is empty, set to '${default_value}'"
    VARS["${var_name}"]="${default_value}"
  else
    debug "VARS['${var_name}'] is set to '${VARS[$var_name]}'"
  fi
}

generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}

generate_salt() {
  if ! is_running_in_interactive_restoring_mode; then
    uuidgen | tr -d '-'
  fi
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
  if [[ "$var_name" != "db_restore_path" ]] && [[ "$var_name" != "without_key" ]]; then
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

stage3(){
  debug "Starting stage 3: read values from inventory file"
  read_inventory
  setup_vars
  if is_running_in_upgrade_mode; then
    assert_upgrade_allowed
  else
    assert_keitaro_not_installed
  fi
}

fix_db_engine() {
  local detected_db_engine
  debug "Detected installer with version ${INSTALLED_VERSION} which possibly sets wrong db_engine"
  detected_db_engine=$(detect_db_engine)
  debug "Detected engine - '${detected_db_engine}', engine in the inventory - '${VARS['db_engine']}'"
  if decteted_db_engine_doesnt_match_inventory "${detected_db_engine}"; then
    debug "Detected engine and engine in the inventory are not matching, reconfiguring"
    VARS['db_engine']="${detected_db_engine}"
    write_inventory_file
    expand_ansible_tags_with_tag "tune-mariadb"
  else
    debug "Everything looks good, don't need to reconfigure db engine"
  fi
}


decteted_db_engine_doesnt_match_inventory() {
  local detected_db_engine="${1}"
  [[
    ("${detected_db_engine}" == "${DB_ENGINE_INNODB}" || "${detected_db_engine}" == "${DB_ENGINE_INNODB}") &&
      "${detected_db_engine}" != "${VARS['db_engine']}"
  ]]
}

get_user_vars_to_restore_from_dump(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  print_translated "welcome"
  get_user_var 'db_restore_path' 'validate_presence validate_file_existence validate_enough_space_for_dump'
  get_user_var 'salt' 'validate_presence validate_alnumdashdot'
  tables_prefix=$(detect_table_prefix "${VARS['db_restore_path']}")
  if empty "${tables_prefix}"; then
    fail "$(translate 'errors.cant_detect_table_prefix')"
  fi
}

get_ssh_port(){
  local ssh_port
  ssh_port=$(echo "${SSH_CLIENT}" | cut -d' ' -f 3)
  if empty "${ssh_port}"; then
    ssh_port="22"
  fi
  debug "Detected ssh port: ${ssh_port}"
  echo "${ssh_port}"
}

DEFAULT_SSH_PORT="22"

detect_sshd_port() {
  local port
  if ! is_ci_mode && is_installed ss; then
    debug "Detecting sshd port"
    port=$(ss -l -4 -p -n | grep -w tcp | grep -w sshd | awk '{ print $5 }' | awk -F: '{ print $2 }' | head -n1)
    debug "Detected sshd port: ${port}"
  fi
  if empty "${port}"; then
    debug "Reset detected sshd port to 22"
    port="${DEFAULT_SSH_PORT}"
  fi
  echo "${port}"
}

write_inventory_file(){
  debug "Writing inventory file: STARTED"
  create_inventory_file
  print_line_to_inventory_file "[server]"
  print_line_to_inventory_file "localhost"
  print_line_to_inventory_file
  print_line_to_inventory_file "[server:vars]"
  print_line_to_inventory_file "server_ip=${SERVER_IP}"
  print_line_to_inventory_file "php_engine=${VARS['php_engine']}"
  print_line_to_inventory_file "cpu_cores=$(get_cpu_cores)"
  print_line_to_inventory_file "ssh_port=$(get_ssh_port)"
  print_line_to_inventory_file "sshd_port=$(detect_sshd_port)"
  print_line_to_inventory_file "db_engine=${VARS['db_engine']}"

  print_nonempty_inventory_item "salt"
  print_nonempty_inventory_item "license_key" "'"
  print_nonempty_inventory_item "ch_password"
  print_nonempty_inventory_item "db_name"
  print_nonempty_inventory_item "db_user"
  print_nonempty_inventory_item "db_password"
  print_nonempty_inventory_item "db_root_password"
  print_nonempty_inventory_item "db_restore_path"
  print_nonempty_inventory_item "tracker_language"
  print_nonempty_inventory_item "tracker_stability"
  print_nonempty_inventory_item "installed"
  print_nonempty_inventory_item "installer_version"

  handle_changeable_inventory_item "olap_db" "${KCTL_OLAP_DB}" "${OLAP_DB_DEFAULT}"
  handle_changeable_inventory_item "ram_size_mb" "$(get_ram_size_mb)" "$(get_ram_size_mb)"


  debug "Writing inventory file: DONE"
}

print_nonempty_inventory_item() {
  local key="${1}"
  local quote="${2}"
  local value="${VARS[$key]}"
  if isset "${value}"; then
    print_line_to_inventory_file "${key}=${quote}${value}${quote}"
  fi
}

handle_changeable_inventory_item() {
  local key="${1}"
  local key_changed="${key}_changed"
  local new_value="${2}"
  local default_value="${3}"
  local current_value="${VARS["${key}"]}"

  if is_inventory_value_changed "${key_changed}" "${new_value}" "${current_value}"; then
    VARS["${key}"]="${new_value:-${default_value}}"
    VARS["${key_changed}"]="true"
    print_line_to_inventory_file "${key}=${VARS[${key}]}"
    print_line_to_inventory_file "${key_changed}=true"
  else
    print_line_to_inventory_file "${key}=${current_value:-${default_value}}"
  fi
}

is_inventory_value_changed() {
  local key_changed="${1}"
  local new_value="${2}"
  local current_value="${3}"

  ( isset "${VARS[${key_changed}]}" ) || \
    ( isset "${new_value}" && [[ "${new_value}" != "${current_value}" ]] )
}

create_inventory_file() {
  mkdir -p "${INVENTORY_DIR}" || fail "Cant't create keitaro inventory dir ${INVENTORY_DIR}"
  chmod 0750 "${INVENTORY_DIR}" || fail "Cant't set permissions keitaro inventory dir ${INVENTORY_DIR}"
  (echo -n > "${INVENTORY_PATH}" && chmod 0600 "${INVENTORY_PATH}") || \
    fail "Cant't create keitaro inventory file ${INVENTORY_PATH}"
}

get_cpu_cores() {
  cpu_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
  if [[ "$cpu_cores" == "0" ]]; then
    cpu_cores=1
  fi
  echo "$cpu_cores"
}

print_line_to_inventory_file() {
  local line="${1}"
  debug "  '$line'"
  echo "$line" >> "$INVENTORY_PATH"
}

installed_version_has_db_engine_bug() {
  (( $(as_version "${INSTALLED_VERSION}") <= $(as_version "1.5.0") )) || \
    (
      (( $(as_version "${INSTALLED_VERSION}") >= $(as_version "2.23.0") )) && \
      (( $(as_version "${INSTALLED_VERSION}") < $(as_version "2.29.0") ))
    )
}

stage4() {
  debug "Starting stage 4: generate inventory file (running mode is ${RUNNING_MODE})."
  if is_running_in_interactive_restoring_mode; then
    debug "Starting stage 4: Get user vars to restore from dump"
    get_user_vars_to_restore_from_dump
  else
    debug "Skip reading vars from stdin"
  fi
  if is_running_in_upgrade_mode && installed_version_has_db_engine_bug; then
    fix_db_engine
  else
    debug "Current kctl version ${INSTALLED_VERSION} doesn't have db engine problems"
  fi
  debug "Starting stage 4: write inventory file"
  write_inventory_file
}

disable_fastestmirror(){
  local disabling_message="Disabling mirrors in repo files"
  local disabling_command="sed -i -e 's/^#baseurl/baseurl/g; s/^mirrorlist/#mirrorlist/g;'  /etc/yum.repos.d/*"
  run_command "${disabling_command}" "${disabling_message}" "hide_output"

  if [[ "$(get_centos_major_release)" == "7" ]] && is_fastestmirror_enabled; then
    disabling_message="Disabling fastestmirror plugin on Centos7"
    disabling_command="sed -i -e 's/^enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf"
    run_command "${disabling_command}" "${disabling_message}" "hide_output"
  fi
}

FASTESTMIROR_CONF_PATH="/etc/yum/pluginconf.d/fastestmirror.conf"

is_fastestmirror_enabled() {
  file_exists "${FASTESTMIROR_CONF_PATH}" && \
      grep -q '^enabled=1' "${FASTESTMIROR_CONF_PATH}"
}

switch_to_centos8_stream() {
  debug "Switching CentOS 8 -> CentOS Stream 8"
  disable_centos_repo CentOS-Linux-AppStream
  disable_centos_repo CentOS-Linux-BaseOS

  run_command "dnf install centos-release-stream -y"
  run_command "dnf swap centos-{linux,stream}-repos -y"
  run_command "dnf distro-sync -y"
}

disable_centos_repo() {
  local repo_name="${1}"
  local repo_file="/etc/yum.repos.d/${repo_name}.repo"
  debug "Disabling repo ${repo_name}"
  if file_exists "${repo_file}"; then
    run_command "sed -i 's/enabled=1/enabled=0/g' ${repo_file}"
  fi
}
is_centos8_distro(){
  file_content_matches /etc/centos-release '-P' '^CentOS Linux.* 8\b'
}
TRACKER_ADMIN_ROOT=""

install_nginx() {
  if [[ "$(get_centos_major_release)" == "7" ]] && (! file_exists /etc/yum.repos.d/nginx.repo); then
    install_nginx_repo /etc/yum.repos.d/nginx.repo
  fi
  install_package 'nginx'
  install_starting_page
}


install_nginx_repo() {
  local repo_file_path="${1}"
  cat > "${repo_file_path}" <<'EOF'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
EOF
}

install_starting_page() {
  mkdir -p "${TRACKER_ROOT}/admin"
  render_starting_page "${TRACKER_ROOT}/admin/index.html"
  chown -R nginx:nginx "${TRACKER_ROOT}"
  render_nginx_config "/etc/nginx/conf.d/default.conf"
  run_command "sed 's/default_server//g' /etc/nginx/nginx.conf -i"
  start_and_enable_nginx
}


render_starting_page() {
  local starting_page_path="${1}"
  cat > "${starting_page_path}" <<EOF
<!doctype html>
<html lang='en'>
  <head>
    <meta charset='utf-8' />
    <link rel="shortcut icon" href="data:" />
    <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js'></script>
    <script>
       function get_keitaro_admin_status() {
         $.ajax({
                  url: "/admin/",
                  type: 'GET',
                  statusCode: { 402: function(res) { window.location.replace("/admin"); } }
         });
       };
       setInterval(get_keitaro_admin_status,5000);
    </script>
  </head>
  <body>
    <h2>Keitaro is being installed...</h2>
    <h4>This page will be updated automatically after installation is complete.</h4>
  </body>
</html>
EOF
}

render_nginx_config() {
  local default_conf="${1}"
  cat > "${default_conf}" <<EOF
    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         ${TRACKER_ROOT};

        location = / { return 301 /admin/; }
    }
EOF
}

start_and_enable_nginx() {
  run_command 'systemctl start nginx'
  run_command 'systemctl enable nginx'
}

install_packages(){
  if [[ "${RUNNING_MODE}" == "${RUNNING_MODE_UPGRADE}" ]]; then
    debug "Upgrading mode detected, skip installing nginx"
  else
    debug "Running mode is '${KCTL_RUNNING_MODE}', installing nginx"
    install_nginx
  fi
  install_package file
  install_package tar
  install_package epel-release
  install_package "$(get_ansible_package_name)"
  install_ansible_collection "community.mysql"
  install_ansible_collection "containers.podman"
  install_ansible_collection "community.general"
  install_ansible_collection "ansible.posix"
}
clean_packages_metadata() {
  if empty "$WITHOUTH_YUM_UPDATE"; then
    run_command "yum clean all" "Cleaninig yum meta" "hide_output"
  fi
}

stage5(){
  debug "Starting stage 5: upgrade current and install necessary packages"
  disable_fastestmirror
  clean_packages_metadata
  if is_centos8_distro; then
    switch_to_centos8_stream
  fi
  install_packages
}

download_provision(){
  debug "Download provision"
  release_url="https://files.keitaro.io/scripts/${BRANCH}/kctl.tar.gz"
  mkdir -p "${PROVISION_DIRECTORY}"
  run_command "curl -fsSL ${release_url} | tar -xzC ${PROVISION_DIRECTORY}"
}
json2dict() {

  throw() {
    echo "$*" >&2
    exit 1
  }

  BRIEF=1               # Brief. Combines 'Leaf only' and 'Prune empty' options.
  LEAFONLY=0            # Leaf only. Only show leaf nodes, which stops data duplication.
  PRUNE=0               # Prune empty. Exclude fields with empty values.
  NO_HEAD=0             # No-head. Do not show nodes that have no path (lines that start with []).
  NORMALIZE_SOLIDUS=0   # Remove escaping of the solidus symbol (straight slash)

  awk_egrep () {
    local pattern_string=$1

    gawk '{
      while ($0) {
        start=match($0, pattern);
        token=substr($0, start, RLENGTH);
        print token;
        $0=substr($0, start+RLENGTH);
      }
    }' pattern="$pattern_string"
  }

  tokenize () {
    local GREP
    local ESCAPE
    local CHAR

    if echo "test string" | grep -ao -E --color=never "test" >/dev/null 2>&1
    then
      GREP='grep -ao -E --color=never'
    else
      GREP='grep -ao -E'
    fi

    if echo "test string" | grep -o -E "test" >/dev/null 2>&1
    then
      ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
      CHAR='[^[:cntrl:]"\\]'
    else
      GREP=awk_egrep
      ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
      CHAR='[^[:cntrl:]"\\\\]'
    fi

    local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
    local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
    local KEYWORD='null|false|true'
    local SPACE='[[:space:]]+'

    # Force zsh to expand $A into multiple words
    local is_wordsplit_disabled
    is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
    if [ "$is_wordsplit_disabled" != 0 ]; then setopt shwordsplit; fi
    $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | grep -v -E "^$SPACE$"
    if [ "$is_wordsplit_disabled" != 0 ]; then unsetopt shwordsplit; fi
  }

  parse_array () {
    local index=0
    local ary=''
    read -r token
    case "$token" in
      ']') ;;
      *)
        while :
        do
          parse_value "$1" "[$index]"
          index=$((index+1))
          ary="$ary""$value"
          read -r token
          case "$token" in
            ']') break ;;
            ',') ary="$ary," ;;
            *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
        ;;
    esac
    [ "$BRIEF" -eq 0 ] && value=$(printf '[%s]' "$ary") || value=
    :
  }

  parse_object () {
    local key
    local obj=''
    read -r token
    case "$token" in
      '}') ;;
      *)
        while :
        do
          case "$token" in
            '"'*'"') key=$token ;;
            *) throw "EXPECTED string GOT ${token:-EOF}" ;;
          esac
          read -r token
          case "$token" in
            ':') ;;
            *) throw "EXPECTED : GOT ${token:-EOF}" ;;
          esac
          read -r token
          local json_key=${key//\"}
          parse_value "$1" "$json_key" "."
          obj="$obj$key:$value"
          read -r token
          case "$token" in
            '}') break ;;
            ',') obj="$obj," ;;
            *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
      ;;
    esac
    [ "$BRIEF" -eq 0 ] && value=$(printf '{%s}' "$obj") || value=
    :
  }

  parse_value () {
    local jpath="${1:+$1$3}$2" isleaf=0 isempty=0 print=0
    case "$token" in
      '{') parse_object "$jpath" ;;
      '[') parse_array  "$jpath" ;;
      # At this point, the only valid single-character tokens are digits.
      ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
      *) value=$token
        # if asked, replace solidus ("\/") in json strings with normalized value: "/"
        [ "$NORMALIZE_SOLIDUS" -eq 1 ] && value="${value//\\}"
        isleaf=1
        [ "$value" = '""' ] && isempty=1
        ;;
    esac
    [ "$value" = '' ] && return
    [ "$NO_HEAD" -eq 1 ] && [ -z "$jpath" ] && return

    [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && [ $PRUNE -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 1 ] && [ "$isempty" -eq 0 ] && print=1
    [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && \
      [ $PRUNE -eq 1 ] && [ $isempty -eq 0 ] && print=1
    [ "$print" -eq 1 ] && [ "$value" != 'null' ] && print_value "$jpath" "$value"
    #printf "['%s']=%s " "$jpath" "$value"
    :
  }

  print_value() {
    local jpath="$1" value="$2"
    printf "['%s']=%s " "$jpath" "$value"
  }

  json_parse () {
    read -r token
    parse_value
    read -r token
    case "$token" in
      '') ;;
      *) throw "EXPECTED EOF GOT $token" ;;
    esac
  }

  echo "("; (tokenize | json_parse); echo ")"
}

write_inventory_on_finish() {
  debug "Signaling successful installation by writing 'installed' flag to the inventory file"
  VARS['db_password']=""
  VARS['db_restore_path']=""
  VARS['db_root_password']=""
  VARS['installed']=true
  VARS['installer_version']="${RELEASE_VERSION}"
  VARS['license_key']=""
  VARS['salt']=""
  VARS['tracker_language']=""
  VARS['tracker_stability']=""
  reset_changeable_values
  write_inventory_file
}


reset_changeable_values() {
  for key in "${!VARS[@]}"; do
    if [[ "${key}" =~ _changed$ ]]; then
      debug "resetting key VARS[${key}]"
      VARS["${key}"]=""
    fi
  done
}


ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^(fatal|failed): "
ANSIBLE_FAILURE_JSON_FILEPATH="${WORKING_DIR}/ansible_failure.json"
ANSIBLE_LAST_TASK_LOG="${WORKING_DIR}/ansible_last_task.log"

run_ansible_playbook(){
  local env=""
  env="${env} ANSIBLE_FORCE_COLOR=true"
  env="${env} ANSIBLE_CONFIG=${PLAYBOOK_DIRECTORY}/ansible.cfg"
  env="${env} KCTL_BRANCH=${BRANCH}"
  env="${env} PROVISION_BIN_DIRECTORY=${PROVISION_BIN_DIRECTORY}"
  env="${env} KCTL_RUNNING_MODE=${RUNNING_MODE}"
  env="${env} KCTL_TRACKER_VERSION_TO_INSTALL=${KCTL_TRACKER_VERSION_TO_INSTALL}"

  if [ -f "$DETECTED_PREFIX_PATH" ]; then
    env="${env} TABLES_PREFIX='$(cat "${DETECTED_PREFIX_PATH}" | head -n1)'"
    rm -f "${DETECTED_PREFIX_PATH}"
  fi
  local command
  command="${env} $(get_ansible_playbook_command) -vvv -i ${INVENTORY_PATH} ${PLAYBOOK_DIRECTORY}/playbook.yml"
  if isset "$ANSIBLE_TAGS"; then
    command="${command} --tags ${ANSIBLE_TAGS}"
  fi

  if isset "$ANSIBLE_IGNORE_TAGS"; then
    command="${command} --skip-tags ${ANSIBLE_IGNORE_TAGS}"
  fi
  run_command "${command}" '' '' '' '' 'print_ansible_fail_message'
}

get_ansible_playbook_command() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "ansible-playbook-3"
  else
    echo "ansible-playbook"
  fi
}

print_ansible_fail_message(){
  local current_command_script="${1}"
  if ansible_task_found; then
    debug "Found last ansible task"
    print_tail_content_of "$CURRENT_COMMAND_ERROR_LOG"
    cat "$CURRENT_COMMAND_OUTPUT_LOG" | remove_text_before_last_pattern_occurence "$ANSIBLE_TASK_HEADER" > "$ANSIBLE_LAST_TASK_LOG"
    print_ansible_last_task_info
    print_ansible_last_task_external_info
    rm "$ANSIBLE_LAST_TASK_LOG"
  else
    print_common_fail_message "$current_command_script"
  fi
}

ansible_task_found(){
  grep -qE "$ANSIBLE_TASK_HEADER" "$CURRENT_COMMAND_OUTPUT_LOG"
}

print_ansible_last_task_info(){
  echo "Task info:"
  head -n2 "$ANSIBLE_LAST_TASK_LOG" | sed -r 's/\*+$//g' | add_indentation
}

print_ansible_last_task_external_info(){
  if ansible_task_failure_found; then
    debug "Found last ansible failure"
    cat "$ANSIBLE_LAST_TASK_LOG" \
      | keep_json_only \
      > "$ANSIBLE_FAILURE_JSON_FILEPATH"
  fi
  print_ansible_task_module_info
  rm "$ANSIBLE_FAILURE_JSON_FILEPATH"
}

ansible_task_failure_found(){
  grep -qP "$ANSIBLE_TASK_FAILURE_HEADER" "$ANSIBLE_LAST_TASK_LOG"
}


keep_json_only(){
  # The json with error is inbuilt into text. The structure of text is about:
  #
  # TASK [$ROLE_NAME : "$TASK_NAME"] *******
  # task path: /path/to/task/file.yml:$LINE
  # .....
  # fatal: [localhost]: FAILED! => {
  #     .....
  #     failure JSON
  #     .....
  # }
  # .....
  #
  # So, first remove all before "fatal: [localhost]: FAILED! => {" line
  # then replace first line to just '{'
  # then remove all after '}'
  sed -n -r "/${ANSIBLE_TASK_FAILURE_HEADER}/,\$p" \
    | sed '1c{' \
    | sed -e '/^}$/q'
  }

remove_text_before_last_pattern_occurence(){
  local pattern="${1}"
  sed -n -r "H;/${pattern}/h;\${g;p;}"
}

print_ansible_task_module_info(){
  declare -A   json
  eval "json=$(cat "$ANSIBLE_FAILURE_JSON_FILEPATH" | json2dict)" 2>/dev/null
  ansible_module="${json['invocation.module_name']}"
  if isset "${json['invocation.module_name']}"; then
    echo "Ansible module: ${json['invocation.module_name']}"
  fi
  if isset "${json['msg']}"; then
    print_field_content "Field 'msg'" "${json['msg']}"
  fi
  if need_print_stdout_stderr "$ansible_module" "${json['stdout']}" "${json['stderr']}"; then
    print_field_content "Field 'stdout'" "${json['stdout']}"
    print_field_content "Field 'stderr'" "${json['stderr']}"
  fi
  if need_print_full_json "$ansible_module" "${json['stdout']}" "${json['stderr']}" "${json['msg']}"; then
    print_content_of "$ANSIBLE_FAILURE_JSON_FILEPATH"
  fi
}

print_field_content(){
  local field_caption="${1}"
  local field_content="${2}"
  if empty "${field_content}"; then
    echo "${field_caption} is empty"
  else
    echo "${field_caption}:"
    echo -e "${field_content}" | fold -s -w $((${COLUMNS:-80} - INDENTATION_LENGTH)) | add_indentation
  fi
}

need_print_stdout_stderr(){
  local ansible_module="${1}"
  local stdout="${2}"
  local stderr="${3}"
  isset "${stdout}"
  local is_stdout_set=$?
  isset "${stderr}"
  local is_stderr_set=$?
  [[ "$ansible_module" == 'cmd' || ${is_stdout_set} == "${SUCCESS_RESULT}" || ${is_stderr_set} == "${SUCCESS_RESULT}" ]]
}

need_print_full_json(){
  local ansible_module="${1}"
  local stdout="${2}"
  local stderr="${3}"
  local msg="${4}"
  need_print_stdout_stderr "$ansible_module" "$stdout" "$stderr"
  local need_print_output_fields=$?
  isset "$msg"
  is_msg_set=$?
  [[ ${need_print_output_fields} != "${SUCCESS_RESULT}" && ${is_msg_set} != "${SUCCESS_RESULT}"  ]]
}

get_printable_fields(){
  local ansible_module="${1}"
  local fields="${2}"
  echo "$fields"
}

stage6() {
  debug "Starting stage 6: run ansible playbook"
  expand_ansible_tags_on_upgrade
  download_provision
  run_ansible_playbook
  clean_up
  write_inventory_on_finish
}

print_successful_message(){
  print_with_color "$(translate "messages.successful_${RUNNING_MODE}")" 'green'
  print_with_color "$(translate 'messages.visit_url')" 'green'
  print_url
}

print_url() {
  print_with_color "http://${SERVER_IP}/admin" 'light.green'
}

print_credentials_notice() {
  local notice=""
  notice=$(translate 'messages.successful.use_old_credentials')
  print_with_color "${notice}" 'yellow'
}

upgrade_packages() {
  if empty "$WITHOUTH_YUM_UPDATE"; then
    debug "Upgrading packages"
    if [[ "$(get_centos_major_release)" == "7" ]]; then
      run_command "yum update -y"
    else
      run_command "yum update -y --nobest"
    fi
  fi
}
stage7() {
  upgrade_packages
  print_successful_message
}

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html

install(){
  init "$@"
  stage1 "$@"               # initial script setup
  stage2                    # make some asserts
  stage3                    # read vars from the inventory file
  stage4                    # get and save vars to the inventory file
  stage5                    # install related packages
  stage6                    # run ansible playbook
  stage7                    # upgrade packages
}

install "$@"
