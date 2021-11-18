#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions


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
      trap "$func $sig" "$sig";
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
TOOL_NAME='kctl'

assert_caller_root(){
  debug 'Ensure script has been running by root'
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual checking of current user"
  else
    if [[ "$EUID" == "$ROOT_UID" ]]; then
      debug 'OK: current user is root'
    else
      debug 'NOK: current user is not root'
      fail "$(translate errors.must_be_root)"
    fi
  fi
}


assert_installed(){
  local program="${1}"
  local error="${2}"
  if ! is_installed "$program"; then
    fail "$(translate "${error}")" "see_logs"
  fi
}

USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE="2.12"
KEITARO_LOCK_FILEPATH="${WEBAPP_ROOT}/var/install.lock"

assert_keitaro_not_installed(){
  debug 'Ensure keitaro is not installed yet'
  if is_keitaro_installed; then
    debug 'NOK: keitaro is already installed'
    print_err "$(translate messages.keitaro_already_installed)" 'yellow'
    show_credentials
    clean_up
    exit "${KEITARO_ALREADY_INSTALLED_RESULT}"
  else
    debug 'OK: keitaro is not installed yet'
  fi
}

is_keitaro_installed() {
   debug "We will use new algorithm for installation check sicne ${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE} (incl.)"
   if should_use_new_algorithm_for_installation_check; then
     debug "Current version is ${INSTALLED_VERSION} - using new algorithm (check 'installed' flag in the inventory file)"
     isset "${VARS['installed']}"
   else
     debug "Current version is ${INSTALLED_VERSION} - using old algorithm (check '${KEITARO_LOCK_FILEPATH}' file)"
     is_file_existing "${KEITARO_LOCK_FILEPATH}" no
   fi
}

should_use_new_algorithm_for_installation_check() {
  (( $(as_version "${INSTALLED_VERSION}") >= $(as_version "${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE}") ))
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
#





is_directory_exist(){
  local directory="${1}"
  local result_on_skip="${2}"
  debug "Checking ${directory} directory existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of ${directory} directory existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${directory} directory does not exist"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${directory} directory exists"
    return ${SUCCESS_RESULT}
  fi
  if [ -d "${directory}" ]; then
    debug "YES: ${directory} directory exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${directory} directory does not exist"
    return ${FAILURE_RESULT}
  fi
}
#





is_file_content_matching(){
  local file="${1}"
  local pattern="${2}"
  local result_on_skip="${3}"
  debug "Checking ${file} file matching with pattern '${pattern}'"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of ${file} file matching disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${file} file does not match '${pattern}'"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  fi
  if test -f "$file" && grep -q "$pattern" "$file"; then
    debug "YES: ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not match '${pattern}"
    return ${FAILURE_RESULT}
  fi
}

is_file_existing(){
  local file="${1}"
  local result_on_skip="${2}"
  debug "Checking ${file} file existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of ${file} file existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${file} file does not exist"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${file} file exists"
    return ${SUCCESS_RESULT}
  fi
  if [ -f "${file}" ]; then
    debug "YES: ${file} file exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not exist"
    return ${FAILURE_RESULT}
  fi
}
#





is_path_exist(){
  local path="${1}"
  local result_on_skip="${2}"
  debug "Checking ${path} path existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual check of ${path} path existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${path} path does not exist"
      return ${FAILURE_RESULT}
    fi
    debug "YES: simulate ${path} path exists"
    return ${SUCCESS_RESULT}
  fi
  if [ -e "${path}" ]; then
    debug "YES: ${path} path exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${path} path does not exist"
    return ${FAILURE_RESULT}
  fi
}
build_certbot_command() {
  if is_ci_mode; then
    echo "/usr/bin/certbot"
  else
    echo "/usr/bin/docker run --network host --rm -it $(dockerized_certbot_volumes) certbot/certbot"
  fi
}

DOCKERIZED_CERTBOT_VOLUME_PATHS="/etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt /var/www/keitaro"

dockerized_certbot_volumes() {
  local dockerized_certbot_volumes=""
  for volume_path in ${DOCKERIZED_CERTBOT_VOLUME_PATHS}; do
    dockerized_certbot_volumes="${dockerized_certbot_volumes} -v ${volume_path}:${volume_path}"
  done
  echo "${dockerized_certbot_volumes}"
}

#






set_ui_lang(){
  if empty "$UI_LANG"; then
    UI_LANG=$(detect_language)
    if empty "$UI_LANG"; then
      UI_LANG="en"
    fi
  fi
  debug "Language: ${UI_LANG}"
}


detect_language(){
  detect_language_from_vars "$LC_ALL" "$LC_MESSAGES" "$LANG"
}


detect_language_from_vars(){
  while [[ ${#} -gt 0 ]]; do
    if isset "${1}"; then
      detect_language_from_var "${1}"
      break
    fi
    shift
  done
}


detect_language_from_var(){
  local lang_value="${1}"
  if [[ "$lang_value" =~ ^ru_[[:alpha:]]+\.UTF-8$ ]]; then
    echo ru
  else
    echo en
  fi
}


get_ui_lang(){
  if empty "$UI_LANG"; then
    set_ui_lang
  fi
  echo "$UI_LANG"
}


translate(){
  local key="${1}"
  local i18n_key
  i18n_key=$(get_ui_lang).$key
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
  IFS="=" read name value <<< "${substitution}"
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

force_utf8_input(){
  if locale -a 2>/dev/null | grep -q en_US.UTF-8; then
    LC_CTYPE=en_US.UTF-8
  else
    debug "Locale en_US.UTF-8 is not defined. Skip setting LC_CTYPE"
    return
  fi
  if [ -f /proc/$$/fd/1 ]; then
    stty -F /proc/$$/fd/1 iutf8
  fi
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
print_prompt_error(){
  local error_key="${1}"
  error=$(translate "validation_errors.$error_key")
  print_with_color "*** ${error}" 'red'
}

print_prompt_help(){
  local var_name="${1}"
  print_translated "prompts.$var_name.help"
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

fail() {
  local message="${1}"
  local see_logs="${2}"
  log_and_print_err "*** $(translate errors.program_failed) ***"
  log_and_print_err "$message"
  if isset "$see_logs"; then
    log_and_print_err "$(translate errors.see_logs)"
  fi
  print_err
  clean_up
  exit ${FAILURE_RESULT}
}
#




common_parse_options(){
  local option="${1}"
  local argument="${2}"
  case $option in
    l|L)
      case $argument in
        en)
          UI_LANG=en
          ;;
        ru)
          UI_LANG=ru
          ;;
        *)
          print_err "-L: language '$argument' is not supported"
          exit ${FAILURE_RESULT}
          ;;
      esac
      ;;
    v)
      version
      ;;
    h)
      help
      ;;
    s)
      SKIP_CHECKS=true
      ;;
    p)
      PRESERVE_RUNNING=true
      ;;
    *)
      wrong_options
      ;;
  esac
}


help(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    usage_ru_header
    help_ru
    help_ru_common
  else
    usage_en_header
    help_en
    help_en_common
  fi
  exit ${SUCCESS_RESULT}
}


usage(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    usage_ru
  else
    usage_en
  fi
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


usage_ru(){
  usage_ru_header
  print_err "Попробуйте '${SCRIPT_NAME} -h' для большей информации."
  print_err
}


usage_en(){
  usage_en_header
  print_err "Try '${SCRIPT_NAME} -h' for more information."
  print_err
}


usage_ru_header(){
  print_err "Использование: $SCRIPT_NAME [OPTION]..."
}


usage_en_header(){
  print_err "Usage: $SCRIPT_NAME [OPTION]..."
}


help_ru_common(){
  print_err "Интернационализация:"
  print_err "  -L LANGUAGE              задать язык - en или ru соответсвенно для английского или русского языка"
  print_err
  print_err "Разное:"
  print_err "  -h                       показать эту справку выйти"
  print_err
  print_err "  -v                       показать версию и выйти"
  print_err
}


help_en_common(){
  print_err "Internationalization:"
  print_err "  -L LANGUAGE              set language - either en or ru for English and Russian appropriately"
  print_err
  print_err "Miscellaneous:"
  print_err "  -h                       display this help text and exit"
  print_err
  print_err "  -v                       display version information and exit"
  print_err
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
    chmod 0700 "${ETC_DIR}" &&
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
  find "${log_dir}" -name "${log_filename}-*" | sort | head -n -${LOGS_TO_KEEP} | xargs rm -f
}

create_log() {
  local log_path="${1}"
  if [[ "${TOOL_NAME}" == "install" ]] && ! is_ci_mode; then
    (umask 066 && touch "${log_path}")
  else
    touch "${log_path}"
  fi
}

init() {
  init_kctl
  force_utf8_input
  debug "Starting init stage: log basic info"
  debug "Command: ${SCRIPT_COMMAND}"
  debug "Script version: ${RELEASE_VERSION}"
  debug "User ID: "$EUID""
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGINT SIGTERM
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

print_err(){
  local message="${1}"
  local color="${2}"
  print_with_color "$message" "$color" >&2
}
#





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
  if isset "$PRESERVE_RUNNING"; then
    print_command_status "$command" 'SKIPPED' 'yellow' "$hide_output"
    debug "Actual running disabled"
  else
    really_run_command "${command}" "${hide_output}" "${allow_errors}" "${run_as}" \
        "${print_fail_message_method}" "${output_log}"
      fi
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
      fail "${fail_message}" "see_logs"
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
  rmdir $(dirname "$current_command_script")
}

start_or_reload_nginx(){
  if (is_file_existing "/run/nginx.pid" && [[ -s "/run/nginx.pid" ]]) || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "nginx -s reload" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
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

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.29.14'
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

if empty "${KCTL_COMMAND}"  && [ "${TOOL_NAME}" = "install" ]; then
  SCRIPT_URL="${KEITARO_URL}/${TOOL_NAME}.sh"
  SCRIPT_COMMAND="curl -fsSL "$SCRIPT_URL" | bash -s -- ${TOOL_ARGS}"
elif empty "${KCTL_COMMAND}" && [ "${TOOL_NAME}" = "kctl" ]; then
  SCRIPT_COMMAND="kctl ${TOOL_ARGS}"
elif empty "${KCTL_COMMAND}"; then
  SCRIPT_COMMAND="kctl-${TOOL_NAME} ${TOOL_ARGS}"
else
  SCRIPT_COMMAND="${KCTL_COMMAND} ${TOOL_ARGS}"
fi
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You should run this program as root.'
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

DICT['ru.errors.program_failed']='ОШИБКА ВЫПОЛНЕНИЯ ПРОГРАММЫ'
DICT['ru.errors.must_be_root']='Эту программу может запускать только root.'
DICT['ru.errors.upgrade_server']='Необходимо обновить конфигурацию. Пожалуйста, обратитесь в службу поддержки Keitaro.'
DICT['ru.errors.run_command.fail']='Ошибка выполнения текущей команды'
DICT['ru.errors.run_command.fail_extra']=''
DICT['ru.errors.terminated']='Выполнение прервано'
DICT['ru.errors.unexpected']='Непредвиденная ошибка'
DICT['ru.errors.cant_upgrade']='Невозможно запустить upgrade т.к. установка не выполнена или произошла с ошибкой'
DICT['ru.certbot_errors.another_proccess']="Другой процесс certbot уже запущен"
DICT['ru.messages.generating_nginx_vhost']="Генерируется конфигурация для сайта :domain:"
DICT['ru.messages.reloading_nginx']="Перезагружается nginx"
DICT['ru.messages.nginx_is_not_running']="Nginx не запущен"
DICT['ru.messages.starting_nginx']="Запускается nginx"
DICT['ru.messages.skip_nginx_conf_generation']="Пропуск генерации конфигурации nginx"
DICT['ru.messages.run_command']='Выполняется команда'
DICT['ru.messages.successful']='Готово!'
DICT['ru.no']='нет'
DICT['ru.validation_errors.validate_domains_list']=$(cat <<-END
	Укажите список доменных имён через запятую без пробелов (например domain1.tld,www.domain1.tld).
	Каждое доменное имя должно сстоять только из букв, цифр и тире и содержать хотя бы одну точку.
	Домены длиной более 64 символов не поддерживаются.
END
)
DICT['ru.validation_errors.validate_absence']='Значение не должно быть задано'
DICT['ru.validation_errors.validate_presence']='Введите значение'
DICT['ru.validation_errors.validate_yes_no']='Ответьте "да" или "нет" (можно также ответить "yes" или "no")'

kctl_doctor(){
  kctl_install "full-upgrade" "kctl-doctor.log"
}

MIN_ROLLBACK_VERSION='9.13.0'

kctl_downgrade() {
  local rollback_version="${1}"
  if empty "${rollback_version}"; then
    fail "$(translate errors.rollback_version_is_empty)" "see_logs"
  elif is_rollback_version_valid "${rollback_version}"; then
    fail "$(translate errors.rollback_version_is_incorrect)"
  fi

  kctl_install "upgrade,upgrade-tracker" "kctl-downgrade.log" "-a '${rollback_version}'"
}

is_rollback_version_valid() {
  local rollback_version="${1}"
  [[ "${rollback_version}" == "lastest-stable" ]] ||
     (( $(as_version "${rollback_version}") <  $(as_version "${MIN_ROLLBACK_VERSION}") ))
}

PEM_SPLITTER="-----BEGIN CERTIFICATE-----"

kctl_fix_le_certs_2021_09_30_issues() {
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
  domain_name=$(basename $(dirname "${certificate_path}"))
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
  local last_certificate_content="${PEM_SPLITTER}${chain_content##*${PEM_SPLITTER}}"
  echo "$last_certificate_content" | openssl x509 -text | grep 'Issuer' | grep 'DST Root CA X3' -q
}


remove_last_certificate_from_chain() {
  local certificate_path="${1}"
  local certificate_chain_content
  certificate_chain_content="$(< "${certificate_path}")"
  local certificate_chain_wo_x3_content="${certificate_chain_content%${PEM_SPLITTER}*}"
  echo "${certificate_chain_wo_x3_content}" > "${certificate_path}"
}

kctl_install() {
  local tags="${1}"
  local log_file_name="${2}"
  local extra_options=${3}
  local log_file_path="${KCTL_LOG_DIR}/${log_file_name}"
  debug "Run command: curl -fsSL4 '${KEITARO_URL}/install.sh' | bash -s -- -rt '${tags}'  -o '${log_file_path}'"
  curl -fsSL4 "${KEITARO_URL}/install.sh" | KCTL_COMMAND="${SCRIPT_COMMAND}" bash -s -- -rt "${tags}"  -o "${log_file_path}" "${extra_options}"
}
kctl_renew_certificates() {
  local successfully_renewed_flag_filepath="/var/lib/letsencrypt/.renewed"
  local renew_args="--allow-subset-of-names --renew-hook 'touch ${successfully_renewed_flag_filepath}'"
  local message="Renewing LE certificates"
  local log_path="${LOG_DIR}/${TOOL_NAME}-renew-certificates.log"
  local command

  command="$(build_certbot_command) renew ${renew_args}"
  LOG_PATH="${log_path}"
  init_log "${log_path}"

  debug "Renewing certificates"
  if run_command "${command}" "${message}" 'hide_output' 'allow_errors' > /dev/null; then
    if is_file_existing "${successfully_renewed_flag_filepath}"; then
      debug "Some certificates have been renewed. Removing flag file ${successfully_renewed_flag_filepath} and reloading nginx"
      command="rm -f '${successfully_renewed_flag_filepath}' && systemctl reload nginx"
      run_command "${command}" "" 'hide_output' > /dev/null
    else
      debug "Certificates have not been updated."
    fi
  fi
}

kctl_show_help(){
  echo "kctl - Keitaro management tool"
  echo ""
  echo "Usage:
   kctl upgrade             - upgrades system & tracker
   kctl doctor              - fixes common problems 
   kctl renew-certificates  - renews LE certificates
   kctl downgrade <version> - downgrades tracker to version"
}

kctl_show_version(){
  echo "kctl v${RELEASE_VERSION}"
}

kctl_upgrade(){
  kctl_install "upgrade" "kctl-upgrade.log"
}

on_exit(){
  exit 1
}

CURRENT_DATETIME="$(date +%Y%m%d%H%M)"
declare -A DICT

DICT['en.errors.rollback_version_is_empty']='Rollback version not specified'
DICT['en.errors.rollback_version_is_incorrect']="Version can't be less than ${MIN_ROLLBACK_VERSION}"
DICT['en.errors.see_logs']="Evaluating log saved to ${LOG_PATH}. Please rerun ${TOOL_NAME} ${*} after resolving problems."
DICT['en.errors.invalid_options']="Invalid option ${1}. Try 'kctl help' for more information."


DICT['ru.errors.rollback_version_is_empty']='Не указана версия для отката'
DICT['ru.errors.rollback_version_is_incorrect']="Версия не может быть ниже ${MIN_ROLLBACK_VERSION}"
DICT['ru.errors.see_logs']="Журнал выполнения сохранён в ${LOG_PATH}. Пожалуйста запустите ${TOOL_NAME} ${*} после устранения возникших проблем."
DICT['ru.errors.invalid_options']="Неправильный параметр ${1}. Используйте 'kctl help' чтобы узнать подробнее"

on_exit(){
  exit 1
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


init "$@"
action="${1}"
assert_caller_root
case "${action}" in
  "upgrade")
    kctl_upgrade
    ;;
  "doctor")
    kctl_doctor
    ;;
  "downgrade")
    rollback_version="${2:-latest-stable}"
    kctl_downgrade "${rollback_version}"
    ;;
  "renew-certificates")
    kctl_renew_certificates
    ;;
  "fix-le-certs-2021-09-30-issues")
    kctl_fix_le_certs_2021_09_30_issues
    ;;
  help)
    kctl_show_help
    ;;
  version)
    kctl_show_version
    ;;
  *)
    fail "$(translate errors.invalid_options)"
esac
