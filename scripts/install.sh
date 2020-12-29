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
  [[ ! -n $1 ]] && return 1;
  echo "$(eval "echo \${$1[@]:(-1)}")"
}

is_ci_mode() {
  [[ "$EUID" != "$ROOT_UID" || "${CI}" != "" ]]
}

is_pipe_mode(){
  [ "${SELF_NAME}" == 'bash' ]
}


TOOL_NAME='install'

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.23.1'
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

declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You should run this program as root.'
DICT['en.errors.upgrade_server']='You should upgrade the server configuration. Please contact Keitaro support team.'
DICT['en.errors.run_command.fail']='There was an error evaluating current command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.errors.unexpected']='Unexpected error'
DICT['en.messages.generating_nginx_vhost']="Generating nginx config for domain :domain:"
DICT['ru.messages.reloading_nginx']="Reloading nginx"
DICT['ru.messages.nginx_is_not_running']="Nginx is not running"
DICT['ru.messages.starting_nginx']="Starting nginx"
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
DICT['en.validation_errors.validate_yes_no']='Please answer "yes" or "no"'

DICT['ru.errors.program_failed']='ОШИБКА ВЫПОЛНЕНИЯ ПРОГРАММЫ'
DICT['ru.errors.must_be_root']='Эту программу может запускать только root.'
DICT['ru.errors.upgrade_server']='Необходимо обновить конфигурацию. Пожалуйста, обратитесь в службу поддержки Keitaro.'
DICT['ru.errors.run_command.fail']='Ошибка выполнения текущей команды'
DICT['ru.errors.run_command.fail_extra']=''
DICT['ru.errors.terminated']='Выполнение прервано'
DICT['en.errors.unexpected']='Непредвиденная ошибка'
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
DICT['ru.validation_errors.validate_presence']='Введите значение'
DICT['ru.validation_errors.validate_yes_no']='Ответьте "да" или "нет" (можно также ответить "yes" или "no")'


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
    fail "$(translate ${error})" "see_logs"
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
    exit ${KEITARO_ALREADY_INSTALLED_RESULT}
  else
    debug 'OK: keitaro is not installed yet'
  fi
}

is_keitaro_installed() {
   if should_use_new_algorithm_for_installation_check; then
     debug "Current version is ${RELEASE_VERSION} - using new algorithm (check 'installed' flag in the inventory file)"
     isset "${VARS['installed']}"
   else
     debug "Current version is ${RELEASE_VERSION} - using old algorithm (check '${KEITARO_LOCK_FILEPATH}' file)"
     is_file_exist "${KEITARO_LOCK_FILEPATH}" no
   fi
}

should_use_new_algorithm_for_installation_check() {
  (( $(as_version ${RELEASE_VERSION}) >= $(as_version ${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE}) ))
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

is_file_exist(){
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





is_file_matches(){
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

assert_config_relevant_or_upgrade_running(){
  debug 'Ensure configs has been genereated by relevant installer'
  if [[ "${RELEASE_VERSION}" == "${INSTALLED_VERSION}" ]]; then
    debug "Configs has been generated by recent version of installer ${RELEASE_VERSION}"
  elif is_upgrade_mode_set; then
    debug "Upgrade mode detected."
  else
    fail "$(translate 'errors.upgrade_server')"
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
  local expanded_version_string="${version_string}."
  if [[ ${expanded_version_string} =~ ^${AS_VERSION__REGEX}$ ]]; then
    printf "1%03d%03d%03d%03d" ${expanded_version_string//./ }
  else
    printf "1%03d%03d%03d%03d" ''
  fi
}

as_minor_version() {
  local version_string="${1}"
  local version_number=$(as_version "${version_string}")
  local meaningful_version_length=$(( 1 + 2*AS_VERSION__MAX_DIGITS_PER_PART ))
  local zeroes_length=$(( 1 + AS_VERSION__PARTS_TO_KEEP * AS_VERSION__MAX_DIGITS_PER_PART - meaningful_version_length ))
  local meaningful_version=${version_number:0:${meaningful_version_length}}
  printf "%d%0${zeroes_length}d" "${meaningful_version}"
}

detect_installed_version(){
  if empty "${INSTALLED_VERSION}"; then
    detect_inventory_path
    if isset "${DETECTED_INVENTORY_PATH}"; then
      INSTALLED_VERSION=$(grep "^installer_version=" ${DETECTED_INVENTORY_PATH} | sed s/^installer_version=//g)
      debug "Got installer_version='${INSTALLED_VERSION}' from ${DETECTED_INVENTORY_PATH}"
    fi
    if empty ${INSTALLED_VERSION}; then
      debug "Couldn't detect installer_version, resetting to ${VERY_FIRST_VERSION}"
      INSTALLED_VERSION="${VERY_FIRST_VERSION}"
    fi
  fi
}

get_centos_major_release() {
  if isset "${SKIP_CHECKS}"; then
    echo 8
  else
    grep -oP '(?<=release )\d+' /etc/centos-release
  fi
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
    if [[ "${TOOL_NAME}" == "add-site" ]]; then
      tool_args="-D ${VARS['site_domains']} -R ${VARS['site_root']}"
    fi
    if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
      tool_args="-D ${VARS['ssl_domains']}"
    fi
    command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
    run_command "${command}" "Running obsolete ${TOOL_NAME} (v${INSTALLED_VERSION})"
    exit
  fi
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
  local i18n_key=$(get_ui_lang).$key
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
  if ! is_installed file "yes"; then
    install_package file > /dev/stderr
  fi
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
  if ! empty ${VARS[$var_name]}; then
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

install_package(){
  local package="${1}"
  debug "Installing ${package}"
  run_command "yum install -y ${package}"
}

is_installed(){
  local command="${1}"
  debug "Try to find "$command""
  if isset "$SKIP_CHECKS"; then
    debug "SKIPPED: actual checking of '$command' presence skipped"
  else
    if [[ $(sh -c "command -v "$command" -gt /dev/null") ]]; then
      debug "FOUND: "$command" found"
    else
      debug "NOT FOUND: "$command" not found"
      return ${FAILURE_RESULT}
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
  print_err "Использование: "$SCRIPT_NAME" [OPTION]..."
}


usage_en_header(){
  print_err "Usage: "$SCRIPT_NAME" [OPTION]..."
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
  init_log
}

init_kctl_dirs_and_links() {
  if [[ ! -d ${KCTL_ROOT} ]]; then
    if ! create_kctl_dirs_and_links; then
      echo "Can't create keitaro directories" >&2
      exit 1
    fi
  fi
  if [[ ! -d ${WORKING_DIR} ]]; then
    if ! mkdir -p ${WORKING_DIR}; then
      echo "Can't create keitaro working directory ${WORKING_DIR}" >&2
      exit 1
    fi
  fi
}

create_kctl_dirs_and_links() {
  mkdir -p ${INVENTORY_DIR} ${KCTL_BIN_DIR} ${WORKING_DIR} &&
    chmod 0700 ${ETC_DIR} &&
    ln -s ${ETC_DIR} ${KCTL_ETC_DIR} &&
    ln -s ${LOG_DIR} ${KCTL_LOG_DIR} &&
    ln -s ${WORKING_DIR} ${KCTL_WORKING_DIR}
}

init_log() {
  save_previous_log
  create_log
  delete_old_logs
}

save_previous_log() {
  if [[ -f "${LOG_PATH}" ]]; then
    local log_timestamp=$(date -r "${LOG_PATH}" +"%Y%m%d%H%M%S")
    mv "${LOG_PATH}" "${LOG_PATH}-${log_timestamp}"
  fi
}

create_log() {
  mkdir -p ${LOG_DIR}
  mkdir -p ${SSL_LOG_DIR}
  if [[ "${TOOL_NAME}" == "install" ]] && ! is_ci_mode; then
    (umask 066 && touch "${LOG_PATH}")
  else
    touch "${LOG_PATH}"
  fi
}

delete_old_logs() {
  find "${LOG_DIR}" -name "${LOG_FILENAME}-*" | sort | head -n -${LOGS_TO_KEEP} | xargs rm -f
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
  local current_command_script=$(save_command_script "${command}" "${run_as}")
  local evaluated_command=$(command_run_as "${current_command_script}" "${run_as}")
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
  local current_command_dir=$(mktemp -d)
  if isset "$run_as"; then
    chown "$run_as" "$current_command_dir"
  fi
  local current_command_script="${current_command_dir}/${CURRENT_COMMAND_SCRIPT_NAME}"
  echo '#!/usr/bin/env bash' > "${current_command_script}"
  echo 'set -o pipefail' >> "${current_command_script}"
  echo -e "${command}" >> "${current_command_script}"
  debug "$(print_content_of ${current_command_script})"
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
  local fail_message_header=$(translate 'errors.run_command.fail')
  local fail_message=$(eval "$print_fail_message_method" "$current_command_script")
  echo -e "${fail_message_header}\n${fail_message}"
}


print_common_fail_message(){
  local current_command_script="${1}"
  print_content_of ${current_command_script}
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
  if is_file_exist "/var/run/nginx.pid" || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "nginx -s reload" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
  fi
}


detected_license_edition_type() {
  local license_ip="${1}"
  local license_key="${2}"
  local dict_key="license_edition_type_${license_ip}_${license_key}"

  if isset "${DETECTED_VARS[${dict_key}]}"; then
    debug "License edition type is already detected"
  else
    DETECTED_VARS[${dict_key}]=$(detect_license_edition_type "${license_ip}" "${license_key}")
  fi
  echo "${DETECTED_VARS[${dict_key}]}"
}

detect_license_edition_type() {
  local license_ip="${1}"
  local license_key="${2}"
  local license_edition_type=""

  debug "Detecting license edition type for ip ${license_ip} and key ${license_key}"

  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual detecting of license type skipped, using 'trial'"
    license_edition_type="trial"
  else
    local url="${KEITARO_URL}/external_api/licenses/edition_type?key=${license_key}&ip=${license_ip}"
    debug "Getting url '${url}'"
    local license_edition_type="$(curl -fsSL "${url}" 2>&1)"
    debug "Done, result is '${license_edition_type}'"
  fi

  echo "${license_edition_type}"
}


detected_license_ip() {
  if isset "${DETECTED_VARS['license_ip']}"; then
    debug "License ip is already detected"
  else
    DETECTED_VARS['license_ip']=$(detect_license_ip)
  fi
  echo "${DETECTED_VARS['license_ip']}"
}

detect_license_ip() {
  local license_ip=""
  debug "Detecting license IP address"

  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual detecting of server IP skipped, using 127.0.0.1"
    license_ip="127.0.0.1"
  else
    local url="https://myip.keitaro.io"
    debug "Getting url '${url}'"
    license_ip="$(curl -fsSL4 ${url} 2>&1)"
    debug "Done, result is '${license_ip}'"
  fi
  echo "${license_ip}"
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

ensure_license_valid() {
  if ! validate_license "${VARS['license_key']}"; then
    fail "$(translate "validation_errors.validate_license")"
  fi
}

ensure_valid() {
  local option="${1}"
  local var_name="${2}"
  local validation_methods="${3}"
  error="$(get_error "${var_name}" "${validation_methods}")"
  if isset "$error"; then
    print_err "-${option}: $(translate "validation_errors.${error}" "value=${VARS[$var_name]}")"
    exit ${FAILURE_RESULT}
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
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local dump_size_kb=$(du -k "$file" | cut -f1)
  local avail_space_in_kb=$(df "$HOME" | awk 'NR==2 { print $4 }')

  if file --mime-type "$file" | grep -q gzip$; then
    local unpacked_dump_size_in_kb=$((dump_size_kb * 7))
    local needed_space_in_kb=$((unpacked_dump_size_in_kb * 23 / 10))
  else
    local needed_space_in_kb=$((dump_size_kb * 13 / 10))
  fi

  if [[ "$needed_space_in_kb" -gt "$avail_space_in_kb" ]]; then
    local fail_message_header=$(translate 'validation_errors.validate_enough_space_for_dump')
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


validate_ip(){
  local value="${1}"
  [[ "$value" =~  ^[[:digit:]]+(\.[[:digit:]]+){3}$ ]] && valid_ip_segments "$value"
}


valid_ip_segments(){
  local ip="${1}"
  local segments="${ip//./ }"
  for segment in "$segments"; do
    if ! valid_ip_segment $segment; then
      return ${FAILURE_RESULT}
    fi
  done
}

valid_ip_segment(){
  local ip_segment="${1}"
  [ $ip_segment -ge 0 ] && [ $ip_segment -le 255 ]
}
#


FIRST_KEITARO_TABLE_NAME="acl"

validate_keitaro_dump(){
  local file="${1}"
  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  local mime_type="$(detect_mime_type "${file}")"
  debug "Detected mime type: ${mime_type}"
  local get_head_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "head -n 100")"
  if empty "${get_head_chunk}"; then
    return ${FAILURE_RESULT}
  fi
  local tables_prefix="$(detect_tables_prefix "${get_head_chunk}")"
  if empty "${tables_prefix}"; then
    return ${FAILURE_RESULT}
  else
    debug "Detected tables prefix: ${tables_prefix}"
  fi
  if [[ "schema_version" < "${tables_prefix}${FIRST_KEITARO_TABLE_NAME}" ]]; then
    ensure_table_dumped "$get_head_chunk" "schema_version"
  else
    local get_tail_chunk="$(build_get_chunk_command "${mime_type}" "${file}" "tail -n 2000")"
    ensure_table_dumped "$get_tail_chunk" "schema_version"
  fi
}

ensure_table_dumped(){
  local get_table_chunk="${1}"
  local table="${2}"
  command="(set +o pipefail && ${get_table_chunk} | grep -qP $(build_check_table_exists_expression "$table"))"
  message="$(translate 'messages.check_keitaro_dump_validity')"
  run_command "${command}" "${message}" 'hide_output' 'allow_errors' > /dev/stderr
}


detect_tables_prefix(){
  local get_head_chunk="${1}"
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

validate_license_key() {
  local value="${1}"
  [[ "$value" =~  ^[0-9A-Z]{4}(-[0-9A-Z]{4}){3}$ ]]
}

validate_license() {
  local license_key="${1}"

  local license_ip=$(detected_license_ip)
  ensure_license_ip_is_correct "${license_ip}"

  local license_edition_type=$(detected_license_edition_type "${license_ip}" "${license_key}")
  ensure_license_edition_type_is_correct "${license_edition_type}"

  is_license_edition_type_valid "${license_edition_type}"
}


ensure_license_ip_is_correct() {
  local license_ip="${1}"

  if ! validate_ip "${license_ip}"; then
    fail "$(translate 'errors.cant_detect_server_ip')" "see_logs"
  fi
}


ensure_license_edition_type_is_correct() {
  local license_edition_type="${1}"

  if !  [[ " ${LICENSE_EDITION_TYPES[@]} " =~ " ${license_edition_type} " ]]; then
    fail "$(translate 'errors.cant_detect_license_edition')" "see_logs"
  fi
}


is_license_edition_type_valid() {
  local license_edition_type="${1}"
  isset "${license_edition_type}" && [[ "${license_edition_type}" != "$LICENSE_EDITION_TYPE_INVALID" ]]
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

validate_server_ip_matches_license_ip(){
  local value="${1}"
  local server_ip=$(hostname -I | awk '{print $1}')
  [[ "$value" == "$server_ip" ]]
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
KEITARO_ALREADY_INSTALLED_RESULT=2
PHP_ENGINE=${PHP_ENGINE:-roadrunner}
DETECTED_PREFIX_PATH="${WORKING_DIR}/detected_prefix"

LICENSE_EDITION_TYPE_TRIAL="trial"
LICENSE_EDITION_TYPE_COMMERCIAL="commercial"
LICENSE_EDITION_TYPE_INVALID="INVALID"
LICENSE_EDITION_TYPES=("$LICENSE_EDITION_TYPE_TRIAL" "$LICENSE_EDITION_TYPE_COMMERCIAL" "$LICENSE_EDITION_TYPE_INVALID")

INSTALLED_VERSION=""


DICT['en.messages.keitaro_already_installed']='Keitaro is already installed'
DICT['en.messages.check_keitaro_dump_get_tables_prefix']="Getting tables prefix from dump"
DICT['en.messages.check_keitaro_dump_validity']="Checking SQL dump"
DICT['en.messages.successful.use_old_credentials']="The database was successfully restored from the archive. Use old login data"
DICT['en.messages.successful.how_to_enable_ssl']=$(cat <<- END
	You can install free SSL certificates with the following command
	kctl-enable-ssl -D domain1.com,domain2.com
END
)
DICT['en.errors.see_logs']=$(cat <<- END
	Installation log saved to ${LOG_PATH}. Configuration settings saved to ${INVENTORY_PATH}.
	You can rerun \`${SCRIPT_COMMAND}\` with saved settings after resolving installation problems.
END
)
DICT['en.errors.wrong_distro']='This installer works only on CentOS 7.x. Please run this program on the clean CentOS server'
DICT['en.errors.not_enough_ram']='The size of RAM on your server should be at least 2 GB'
DICT['en.errors.keitaro_dump_invalid']='SQL dump is broken'
DICT['en.errors.isp_manager_installed']='You can not install Keitaro on the server with ISP Manager installed. Please run this program on a clean CentOS server.'
DICT['en.errors.vesta_cp_installed']='You can not install Keitaro on the server with Vesta CP installed. Please run this program on a clean CentOS server.'
DICT['en.errors.apache_installed']='You can not install Keitaro on the server with Apache HTTP server installed. Please run this program on a clean CentOS server.'
DICT['en.errors.cant_detect_server_ip']="The installer couldn't detect the server IP address, please contact Keitaro support team"
DICT['en.errors.cant_detect_license_edition']="The installer couldn't detect the your license edition, please contact Keitaro support team"
DICT['en.errors.dump_restoring_not_available_for_trials']='Dump restoring is not avalable for trial licenses'

DICT['en.prompts.admin_login']='Please enter Keitaro admin login'
DICT['en.prompts.admin_password']='Please enter Keitaro admin password'
DICT['en.prompts.db_name']='Please enter database name'
DICT['en.prompts.db_password']='Please enter database user password'
DICT['en.prompts.db_user']='Please enter database user name'
DICT['en.prompts.db_restore_path']='Please enter the path to the SQL dump file if you want to restore database'
DICT['en.prompts.db_restore_salt']='Please enter the value of the "salt" parameter from the old config (application/config/config.ini.php)'
DICT['en.prompts.license_key']='Please enter license key'
DICT['en.welcome']=$(cat <<- END
	Welcome to Keitaro installer.
	This installer will guide you through the steps required to install Keitaro on your server.
END
)
DICT['en.validation_errors.validate_alnumdashdot']='Only Latin letters, numbers, dashes, underscores and dots allowed'
DICT['en.validation_errors.validate_file_existence']='The file was not found by the specified path, please enter the correct path to the file'
DICT['en.validation_errors.validate_keitaro_dump']='The SQL dump is broken, please specify path to correct SQL dump of Keitaro'
DICT['en.validation_errors.validate_license']='Wrong license key or ip'
DICT['en.validation_errors.validate_enough_space_for_dump']='Dont enough space for restore dump'
DICT['en.validation_errors.validate_license_key']='Please enter valid license key (eg AAAA-BBBB-CCCC-DDDD)'
DICT['en.validation_errors.validate_not_reserved_word']='You are not allowed to use yes/no/true/false as value'
DICT['en.validation_errors.validate_starts_with_latin_letter']='The value must begin with a Latin letter'

DICT['ru.messages.keitaro_already_installed']='Keitaro трекер уже установлен.'
DICT['ru.messages.check_keitaro_dump_get_tables_prefix']="Получаем префикс таблиц из SQL дампа"
DICT['ru.messages.check_keitaro_dump_validity']="Проверяем SQL дамп"
DICT["ru.messages.successful.use_old_credentials"]="База данных успешно восстановлена из архива. Используйте старые данные для входа в систему"
DICT['ru.messages.successful.how_to_enable_ssl']=$(cat <<- END
	Вы можете установить бесплатные SSL сертификаты, выполнив следующую команду:
	kctl-enable-ssl -D domain1.com,domain2.com -L ru
END
)
DICT['ru.errors.see_logs']=$(cat <<- END
	Журнал установки сохранён в ${LOG_PATH}. Настройки сохранены в ${INVENTORY_PATH}.
	Вы можете повторно запустить \`${SCRIPT_COMMAND}\` с этими настройками после устранения возникших проблем.
END
)
DICT['ru.errors.wrong_distro']='Установщик Keitaro работает только в CentOS 7.x. Пожалуйста, запустите эту программу в CentOS дистрибутиве'
DICT['ru.errors.not_enough_ram']='Размер оперативной памяти на вашем сервере должен быть не менее 2 ГБ'
DICT['ru.errors.keitaro_dump_invalid']='Указанный файл не является дампом Keitaro или загружен не полностью.'
DICT['ru.errors.isp_manager_installed']="Программа установки не может быть запущена на серверах с установленным ISP Manager. Пожалуйста, запустите эту программу на чистом CentOS сервере."
DICT['ru.errors.vesta_cp_installed']="Программа установки не может быть запущена на серверах с установленной Vesta CP. Пожалуйста, запустите эту программу на чистом CentOS сервере."
DICT['ru.errors.apache_installed']="Программа установки не может быть запущена на серверах с установленным Apache HTTP server. Пожалуйста, запустите эту программу на чистом CentOS сервере."
DICT['ru.errors.cant_detect_server_ip']='Программа установки не смогла определить IP адрес сервера. Пожалуйста, обратитесь в службу технической поддержки Keitaro'
DICT['ru.errors.cant_detect_license_edition']='Программа установки не смогла определить тип вашей лицензии. Пожалуйста, обратитесь в службу технической поддержки Keitaro'
DICT['ru.errors.dump_restoring_not_available_for_trials']='Восстановление из дампа не доступно для пробных лицензий'
DICT['ru.prompts.admin_login']='Укажите имя администратора Keitaro'
DICT['ru.prompts.admin_password']='Укажите пароль администратора Keitaro'
DICT['ru.prompts.db_name']='Укажите имя базы данных'
DICT['ru.prompts.db_password']='Укажите пароль пользователя базы данных'
DICT['ru.prompts.db_user']='Укажите пользователя базы данных'
DICT['ru.prompts.db_restore_path']='Укажите путь к файлу c SQL дампом, если хотите восстановить базу данных из дампа'
DICT['ru.prompts.db_restore_salt']='Укажите значение параметра salt из старой конфигурации (application/config/config.ini.php)'
DICT['ru.prompts.license_key']='Укажите лицензионный ключ'
DICT['ru.welcome']=$(cat <<- END
	Добро пожаловать в программу установки Keitaro.
	Эта программа поможет собрать информацию необходимую для установки Keitaro на вашем сервере.
END
)
DICT['ru.validation_errors.validate_license_key']='Введите корректный ключ лицензии (например AAAA-BBBB-CCCC-DDDD)'
DICT['ru.validation_errors.validate_alnumdashdot']='Можно использовать только латинские бувы, цифры, тире, подчёркивание и точку'
DICT['ru.validation_errors.validate_starts_with_latin_letter']='Значение должно начинаться с латинской буквы'
DICT['ru.validation_errors.validate_file_existence']='Файл по заданному пути не обнаружен, введите правильный путь к файлу'
DICT['ru.validation_errors.validate_keitaro_dump']='Указанный файл не является дампом Keitaro или загружен не полностью. Укажите путь до корректного SQL дампа'
DICT['ru.validation_errors.validate_not_reserved_word']='Запрещено использовать yes/no/true/false в качестве значения'
DICT['ru.validation_errors.validate_license']='Неверный ключ лицензии или IP'
DICT['ru.validation_errors.validate_enough_space_for_dump']='Недостаточно места для восстановления из дампа'



is_detected_license_edition_type_commercial() {
  local license_ip="$(detected_license_ip)"
  local license_key="${VARS['license_key']}"
  local license_edition_type=$(detected_license_edition_type ${license_ip} ${license_key})
  [[ "${license_edition_type}" == "${LICENSE_EDITION_TYPE_COMMERCIAL}" ]]
}

is_ram_size_mb_changed() {
  ( isset "${VARS['previous_ram_size_mb']}" && [[ "${VARS['previous_ram_size_mb']}" != "${VARS['ram_size_mb']}" ]] ) \
      || ( isset "${VARS['ram_size_mb']}" && [[ "${VARS['ram_size_mb']}" != "$(get_ram_size_mb)" ]] )
}


get_var_from_config(){
  local var="${1}"
  local file="${2}"
  local separator="${3}"
  cat "$file" | \
    grep "^${var}\\b" | \
    grep "${separator}" | \
    head -n1 | \
    awk -F"${separator}" '{print $2}' | \
    awk '{$1=$1; print}' | \
    sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
  }

DETECTED_RAM_SIZE_MB=""

get_ram_size_mb() {
  if empty "${DETECTED_RAM_SIZE_MB}"; then
    if is_ci_mode; then
      DETECTED_RAM_SIZE_MB=2048
    else
      DETECTED_RAM_SIZE_MB=$((free -m | grep Mem: | awk '{print $2}') 2>/dev/null)
    fi
  fi
  echo "${DETECTED_RAM_SIZE_MB}"
}


clean_up(){
  if [ -d "$PROVISION_DIRECTORY" ]; then
    debug "Remove ${PROVISION_DIRECTORY}"
    rm -rf "$PROVISION_DIRECTORY"
  fi
}


write_inventory_on_reconfiguration() {
  debug "Stages 3-5: write inventory on reconfiguration"
  if empty "${DETECTED_INVENTORY_PATH}"; then
    debug "Detecting inventory variables"
    reset_vars_on_reconfiguration
    detect_inventory_variables
  fi
  VARS['installer_version']="${INSTALLED_VERSION}"
  VARS['php_engine']="${PHP_ENGINE}"
  write_inventory_file
}


reset_vars_on_reconfiguration() {
  VARS['admin_login']=''
  VARS['admin_password']=''
  VARS['db_name']=''
  VARS['db_user']=''
  VARS['db_password']=''
  VARS['db_root_password']=''
  VARS['db_engine']=''
}


detect_inventory_variables() {
  if empty "${VARS['license_key']}"; then
    if [[ -f ${WEBAPP_ROOT}/var/license/key.lic ]]; then
      VARS['license_key']="$(cat ${WEBAPP_ROOT}/var/license/key.lic)"
      debug "Detected license key: ${VARS['license_key']}"
    fi
  fi
  if empty "${VARS['db_name']}"; then
    VARS['db_name']="$(get_var_from_keitaro_app_config name)"
    debug "Detected db name: ${VARS['db_name']}"
  fi
  if empty "${VARS['db_user']}"; then
    VARS['db_user']="$(get_var_from_keitaro_app_config user)"
    debug "Detected db user: ${VARS['db_user']}"
  fi
  if empty "${VARS['db_password']}"; then
    VARS['db_password']="$(get_var_from_keitaro_app_config password)"
    debug "Detected db password: ${VARS['db_password']}"
  fi
  if empty "${VARS['db_root_password']}"; then
    VARS['db_root_password']="$(get_var_from_config password ~/.my.cnf '=')"
    debug "Detected db root password: ${VARS['db_root_password']}"
  fi
}


get_var_from_keitaro_app_config() {
  local var="${1}"
  get_var_from_config "${var}" "${WEBAPP_ROOT}/application/config/config.ini.php" '='
}



parse_options(){
  while getopts ":A:K:U:P:F:S:ra:t:i:k:L:l:hvpsw" option; do
    argument=$OPTARG
    ARGS["${option}"]="${argument}"
    case $option in
      A)
        echo "Ignoring -A parameter"
        ;;
      K)
        AUTO_INSTALL="true"
        VARS['license_key']=$argument
        ensure_license_set
        ;;
      U)
        VARS['admin_login']=$argument
        ensure_valid U admin_login "validate_alnumdashdot validate_not_reserved_word validate_starts_with_latin_letter"
        ;;
      P)
        VARS['admin_password']=$argument
        ensure_valid P admin_password "validate_alnumdashdot validate_not_reserved_word"
        ;;
      F)
        VARS['db_restore_path']=$argument
        ;;
      S)
        VARS['db_restore_salt']=$argument
        ;;
      r)
        RECONFIGURE="true"
        ;;
      a)
        CUSTOM_PACKAGE=$argument
        ;;
      t)
        ANSIBLE_TAGS=$argument
        ;;
      i)
        ANSIBLE_IGNORE_TAGS=$argument
        ;;
      w)
        WITHOUTH_YUM_UPDATE="true"
        ;;
      k)
        case $argument in
          8|9)
            KEITARO_RELEASE=$argument
            ;;
          *)
            print_err "Specified Keitaro release '${argument}' is not supported"
            exit ${FAILURE_RESULT}
            ;;
        esac
        ;;
      *)
        common_parse_options "$option" "$argument"
        ;;
    esac
  done
  if isset "${ARGS['U']}" || isset "${ARGS['P']}"; then
    ensure_license_set
  fi
  if isset "${ARGS['F']}" || isset "${ARGS['S']}"; then
    ensure_license_set
    ensure_license_edition_type_is_commercial
    ensure_valid F db_restore_path "validate_presence validate_file_existence validate_keitaro_dump validate_enough_space_for_dump"
    ensure_valid S db_restore_salt "validate_presence validate_alnumdashdot"
  fi
  ensure_options_correct
}


ensure_license_set() {
  ensure_valid K license_key "validate_presence validate_license_key validate_license"
}


ensure_license_edition_type_is_commercial() {
   if ! is_detected_license_edition_type_commercial; then
     fail "$(translate 'errors.dump_restoring_not_available_for_trials')"
   fi
}


help_ru(){
  print_err "$SCRIPT_NAME уставливает и настраивает Keitaro"
  print_err "Пример: "$SCRIPT_NAME" -L ru -K AAAA-BBBB-CCCC-DDDD -U some_username -P some_password"
  print_err
  print_err "Автоматизация:"
  print_err "  -K LICENSE_KEY           задать ключ лицензии"
  print_err
  print_err "  -F DUMP_FILEPATH         задать путь к дампу базы (обязательно наличие -S и -K)"
  print_err
  print_err "  -S SALT                  задать salt при восстановлении из дампа (обязательно наличие -F и -K)"
  print_err
  print_err "  -U ADMIN_USER            задать имя администратора (обязательно наличие -K)"
  print_err
  print_err "  -P ADMIN_PASSWORD        задать пароль администратора (обязательно наличие -K)"
  print_err
  print_err "  -r                       включить режим переконфигурации (несовместимо с -K)"
  print_err
  print_err "Настройка:"
  print_err "  -a PATH_TO_PACKAGE       задать путь к установочному пакету с архивом Keitaro"
  print_err
  print_err "  -t TAGS                  задать список ansible-playbook тегов, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -i TAGS                  задать список игнорируемых ansible-playbook тегов, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -k RELEASE               задать релиз Keitaro, поддерживается 8 и 9"
  print_err
}


help_en(){
  print_err "$SCRIPT_NAME installs and configures Keitaro"
  print_err "Example: "$SCRIPT_NAME" -L en -K AAAA-BBBB-CCCC-DDDD -U some_username -P some_password"
  print_err
  print_err "Script automation:"
  print_err "  -K LICENSE_KEY           set license key"
  print_err
  print_err "  -F DUMP_FILEPATH         set filepath to dump (-S and -K should be specified)"
  print_err
  print_err "  -S SALT                  set salt for dump restoring (-F and -K should be specified)"
  print_err
  print_err "  -U ADMIN_USER            set admin user name (-K should be specified)"
  print_err
  print_err "  -P ADMIN_PASSWORD        set admin password (-K should be specified)"
  print_err
  print_err "  -r                       enables reconfiguration mode (incompatible with -K)"
  print_err
  print_err "Customization:"
  print_err "  -a PATH_TO_PACKAGE       set path to Keitaro installation package"
  print_err
  print_err "  -t TAGS                  set ansible-playbook tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -i TAGS                  set ansible-playbook ignore tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -k RELEASE               set Keitaro release, 8 and 9 are only valid values"
  print_err
}

stage1() {
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  set_ui_lang
}


assert_not_running_under_openvz() {
  debug "Assert we are not running under OpenVZ"
  if is_ci_mode; then
    debug "Detected test mode, skip OpenVZ checks"
    return
  fi

  virtualization_type="$(hostnamectl status | grep Virtualization | awk '{print $2}')"
  debug "Detected virtualization type: '${virtualization_type}'"
  if isset "${virtualization_type}" && [[ "${virtualization_type}" == "openvnz" ]]; then
    fail "Servers with OpenVZ virtualization are not supported"
  fi
}

assert_centos_distro(){
  assert_installed 'yum' 'errors.wrong_distro'
  if ! is_file_exist /etc/centos-release; then
    fail "$(translate errors.wrong_distro)" "see_logs"
  fi
}
MIN_RAM_SIZE_MB=1500

assert_has_enough_ram(){
  debug "Checking RAM size"

  local current_ram_size_mb=$(get_ram_size_mb)
  if [[ "$current_ram_size_mb" -lt "$MIN_RAM_SIZE_MB" ]]; then
    debug "RAM size ${current_ram_size_mb}mb is less than ${MIN_RAM_SIZE_MB}mb, raising error"
    fail "$(translate errors.not_enough_ram)"
  else
    debug "RAM size ${current_ram_size_mb}mb is greater than ${MIN_RAM_SIZE_MB}mb, continuing"
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
  is_file_exist "/sys/kernel/mm/transparent_hugepage/enabled" && is_file_exist "/sys/kernel/mm/transparent_hugepage/defrag"
}

assert_pannels_not_installed(){
  if isset "$SKIP_CHECKS"; then
    debug "SKIPPED: actual checking of panels skipped"
  else
    if is_installed mysql; then
      assert_isp_manager_not_installed
      assert_vesta_cp_not_installed
    fi
  fi
}


assert_isp_manager_not_installed(){
  if is_database_exists roundcube; then
    debug "ISP Manager database detected"
    fail "$(translate errors.isp_manager_installed)"
  fi
}


assert_vesta_cp_not_installed(){
  if is_database_exists admin_default; then
    debug "Vesta CP database detected"
    fail "$(translate errors.vesta_cp_installed)"
  fi
}


is_database_exists(){
  local database="${1}"
  debug "Check if database ${database} exists"
  mysql -Nse 'show databases' 2>/dev/null | tr '\n' ' ' | grep -Pq "${database}"
}
#





assert_apache_not_installed(){
  if isset "$SKIP_CHECKS"; then
    debug "SKIPPED: actual checking of httpd skipped"
  else
    if is_installed httpd; then
      fail "$(translate errors.apache_installed)"
    fi
  fi
}

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_apache_not_installed
  assert_centos_distro
  assert_has_enough_ram
  assert_not_running_under_openvz
  assert_pannels_not_installed
  assert_thp_deactivatable
}

setup_vars(){
  setup_default_value admin_login 'admin'
  setup_default_value admin_password "$(generate_password)"
  setup_default_value db_name 'keitaro'
  setup_default_value db_user 'keitaro'
  setup_default_value db_password "$(generate_password)"
  setup_default_value db_root_password "$(generate_password)"
  setup_default_value db_engine 'tokudb'
  setup_default_value php_engine "${PHP_ENGINE}"
  setup_default_value ssh_port "$(get_ssh_port)"
}

get_ssh_port(){
  local sshport=`echo $SSH_CLIENT | cut -d' ' -f 3`
  if [ -z "$sshport" ]; then
    echo "22"
  else
    if [ "$sshport" != "22" ]; then
      echo "$sshport"
    else
      echo "22"
    fi
  fi
}

setup_default_value(){
  local var_name="${1}"
  local default_value="${2}"
  if empty "${VARS[${var_name}]}"; then
    debug "VARS['${var_name}'] is empty, set to '${default_value}'"
    VARS[${var_name}]=$default_value
  else
    debug "VARS['${var_name}'] is set to '${VARS[$var_name]}'"
  fi
}

generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}

read_inventory(){
  detect_inventory_path
  if isset "${DETECTED_INVENTORY_PATH}"; then
    parse_inventory "${DETECTED_INVENTORY_PATH}"
  fi
}

parse_inventory(){
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
  IFS="=" read var_name value <<< "$line"
  if [[ "$var_name" != 'db_restore_path' ]]; then
    if empty "${VARS[$var_name]}"; then
      VARS[$var_name]=$value
      debug "# read '$var_name' from inventory"
    else
      debug "# $var_name is set from options, skip inventory value"
    fi
    debug "  "$var_name"=${VARS[$var_name]}"
  fi
}

stage3(){
  debug "Starting stage 3: read values from inventory file"
  read_inventory
  setup_vars
  detect_installed_version
}

write_inventory_file(){
  debug "Writing inventory file: STARTED"
  create_inventory_file
  print_line_to_inventory_file "[server]"
  print_line_to_inventory_file "localhost connection=local ansible_user=root"
  print_line_to_inventory_file
  print_line_to_inventory_file "[server:vars]"
  print_line_to_inventory_file "license_ip=$(detected_license_ip)"
  print_line_to_inventory_file "license_key=${VARS['license_key']}"
  print_line_to_inventory_file "db_root_password=${VARS['db_root_password']}"
  print_line_to_inventory_file "db_name=${VARS['db_name']}"
  print_line_to_inventory_file "db_user=${VARS['db_user']}"
  print_line_to_inventory_file "db_password=${VARS['db_password']}"
  print_line_to_inventory_file "db_restore_path=${VARS['db_restore_path']}"
  print_line_to_inventory_file "db_restore_salt=${VARS['db_restore_salt']}"
  print_line_to_inventory_file "admin_login=${VARS['admin_login']}"
  print_line_to_inventory_file "admin_password=${VARS['admin_password']}"
  print_line_to_inventory_file "language=$(get_ui_lang)"
  print_line_to_inventory_file "evaluated_by_installer=yes"
  print_line_to_inventory_file "php_engine=${VARS['php_engine']}"
  print_line_to_inventory_file "cpu_cores=$(get_cpu_cores)"
  print_line_to_inventory_file "ssh_port=${VARS['ssh_port']}"
  local current_ram_size_mb="$(get_ram_size_mb)"
  if is_ram_size_mb_changed; then
     local previous_ram_size_mb="${VARS['previous_ram_size_mb']:-${VARS['ram_size_mb']}}"
     print_line_to_inventory_file "previous_ram_size_mb=${previous_ram_size_mb}"
     print_line_to_inventory_file "ram_size_mb=${current_ram_size_mb}"
  else
     print_line_to_inventory_file "ram_size_mb=${current_ram_size_mb}"
  fi
  if isset "${VARS['installer_version']}"; then
    print_line_to_inventory_file "installer_version=${VARS['installer_version']}"
  else
    print_line_to_inventory_file "installer_version=${RELEASE_VERSION}"
  fi
  if isset "${VARS['db_engine']}"; then
    print_line_to_inventory_file "db_engine=${VARS['db_engine']}"
  fi
  if isset "$KEITARO_RELEASE"; then
    print_line_to_inventory_file "kversion=$KEITARO_RELEASE"
  fi
  if isset "$CUSTOM_PACKAGE"; then
    print_line_to_inventory_file "custom_package=$CUSTOM_PACKAGE"
  fi
  if isset "${VARS['installed']}"; then
    print_line_to_inventory_file "installed=${VARS['installed']}"
  fi
  debug "Writing inventory file: DONE"
}

create_inventory_file() {
  mkdir -p "${INVENTORY_DIR}" -m 0700 || fail "Cant't create keitaro inventory dir ${INVENTORY_DIR}"
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


get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  print_translated "welcome"
  get_user_var 'license_key' 'validate_presence validate_license_key validate_license'
  get_user_db_restore_vars
}


get_user_db_restore_vars(){
  if is_detected_license_edition_type_commercial; then
    get_user_var 'db_restore_path' 'validate_file_existence validate_keitaro_dump validate_enough_space_for_dump'
    if isset "${VARS['db_restore_path']}"; then
      get_user_var 'db_restore_salt' 'validate_presence validate_alnumdashdot'
    fi
  fi
}

stage4(){
  debug "Starting stage 4: generate inventory file"
  if isset "$AUTO_INSTALL"; then
    debug "Skip reading vars from stdin"
  else
    get_user_vars
  fi
  write_inventory_file
}

stage5(){
  debug "Starting stage 5: upgrade current and install necessary packages"
  upgrade_packages
  install_packages
}

upgrade_packages(){
  if empty "$WITHOUTH_YUM_UPDATE"; then
    debug "Upgrading packages"
    if [[ "$(get_centos_major_release)" == "7" ]]; then
      run_command "yum update -y"
    else
      run_command "yum update -y --nobest"
    fi
  fi
}

install_packages(){
  if ! is_installed tar; then
    install_package tar
  fi
  if ! is_installed ansible; then
    install_package epel-release
    install_package ansible
  fi
}

download_provision(){
  debug "Download provision"
  release_url="https://files.keitaro.io/scripts/${BRANCH}/playbook.tar.gz"
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

    if echo "test string" | egrep -ao --color=never "test" >/dev/null 2>&1
    then
      GREP='egrep -ao --color=never'
    else
      GREP='egrep -ao'
    fi

    if echo "test string" | egrep -o "test" >/dev/null 2>&1
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
    local is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
    if [ $is_wordsplit_disabled != 0 ]; then setopt shwordsplit; fi
    $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | egrep -v "^$SPACE$"
    if [ $is_wordsplit_disabled != 0 ]; then unsetopt shwordsplit; fi
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
        [ "$NORMALIZE_SOLIDUS" -eq 1 ] && value=$(echo "$value" | sed 's#\\/#/#g')
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

show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
}

show_credentials(){
  print_with_color "http://$(detected_license_ip)/admin" 'light.green'

  if isset "${VARS['db_restore_path']}"; then
    echo "$(translate 'messages.successful.use_old_credentials')"
  else
    colored_login=$(print_with_color "${VARS['admin_login']}" 'light.green')
    colored_password=$(print_with_color "${VARS['admin_password']}" 'light.green')
    echo -e "login: ${colored_login}"
    echo -e "password: ${colored_password}"
  fi
  echo "$(translate 'messages.successful.how_to_enable_ssl')"
}

ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^(fatal|failed): "
ANSIBLE_FAILURE_JSON_FILEPATH="${WORKING_DIR}/ansible_failure.json"
ANSIBLE_LAST_TASK_LOG="${WORKING_DIR}/ansible_last_task.log"

run_ansible_playbook(){
  local env="ANSIBLE_FORCE_COLOR=true"
  env="${env} ANSIBLE_CONFIG=${PROVISION_DIRECTORY}/ansible.cfg"
  env="${env} ANSIBLE_GATHER_TIMEOUT=30"
  if [ -f "$DETECTED_PREFIX_PATH" ]; then
    env="${env} TABLES_PREFIX='$(cat "${DETECTED_PREFIX_PATH}" | head -n1)'"
    rm -f "${DETECTED_PREFIX_PATH}"
  fi
  local command="${env} ansible-playbook -vvv -i ${INVENTORY_PATH} ${PROVISION_DIRECTORY}/playbook.yml"
  if isset "$ANSIBLE_TAGS"; then
    command="${command} --tags ${ANSIBLE_TAGS}"
  fi
  if isset "$ANSIBLE_IGNORE_TAGS"; then
    command="${command} --skip-tags ${ANSIBLE_IGNORE_TAGS}"
  fi
  run_command "${command}" '' '' '' '' 'print_ansible_fail_message'
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
    echo -e "${field_content}" | fold -s -w $((${COLUMNS:-80} - ${INDENTATION_LENGTH})) | add_indentation
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
  [[ "$ansible_module" == 'cmd' || ${is_stdout_set} == ${SUCCESS_RESULT} || ${is_stderr_set} == ${SUCCESS_RESULT} ]]
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
  [[ ${need_print_output_fields} != ${SUCCESS_RESULT} && ${is_msg_set} != ${SUCCESS_RESULT}  ]]
}

get_printable_fields(){
  local ansible_module="${1}"
  local fields="${2}"
  echo "$fields"
}

stage6(){
  debug "Starting stage 6: run ansible playbook"
  download_provision
  run_ansible_playbook
  clean_up
  show_successful_message
  if isset "$ANSIBLE_TAGS"; then
    debug "Ansible tags is set to '${ANSIBLE_TAGS}' - skip printing credentials"
    if is_upgrade_mode_set; then
      signal_successful_installation
    fi
  else
    signal_successful_installation
    show_credentials
  fi
}

signal_successful_installation() {
  debug "Signaling successful installation by writing 'installed' flag to the inventory file"
  VARS['installed']=true
  VARS['installer_version']="${RELEASE_VERSION}"
  VARS['ram_size_mb']="$(get_ram_size_mb)"
  VARS['previous_ram_size_mb']="${VARS['ram_size_mb']}"
  VARS['db_restore_path']=""
  VARS['db_restore_salt']=""
  write_inventory_file
}

# If installed version less than or equal to version from checkpoint 
# then ANSIBLE_TAGS will be expanded by upgrade-from-x.y tag
# Example: 
#   when UPGRADE_CHECKPOINTS=(1.5 2.0 2.12 2.13)
#     and insalled version is 2.12
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `upgrade-from-2.12` and `upgrade-from-2.13` tags 
UPGRADE_CHECKPOINTS=(1.5 2.0 2.12 2.13 2.16 2.20)

# If installed version less than or equal to version from array value
# then ANSIBLE_TAGS will be expanded by appropriate tags (given from array key)
# Example: 
#   when REPLAY_ROLE_TAGS_ON_UPGRADE_FROM=( ['init']='1.0' ['enable-swap']='2.0' )
#     and insalled version is 2.0
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `enable-swap` tag
declare -A REPLAY_ROLE_TAGS_SINCE=(
  ['create-tracker-user-and-dirs']='2.22.0'
  ['disable-ipv6']='1.0'
  ['disable-selinux']='2.14'
  ['disable-thp']='0.9'
  ['enable-firewall']='1.9'
  ['enable-repo-remi']='2.15'
  ['increase-max-opened-files']='1.0'
  ['install-certbot']='2.16'
  ['install-certs']='1.0'
  ['install-chrony']='2.13'
  ['install-helper-packages']='2.20'
  ['install-postfix']='2.13'
  ['setup-journald']='2.12'
  ['setup-timezone']='0.9'
  ['tune-swap']='2.21.0'
  ['install-php']='2.12'
  ['install-roadrunner']='2.20.4'
  ['tune-php']='2.20.4'
  ['tune-roadrunner']='2.20.4'
  ['install-mariadb']='1.17'
  ['tune-mariadb']='2.20.4'
  ['tune-redis']='2.20.4'
  ['install-nginx']='1.0'
  ['tune-nginx']='2.20.4'
  ['setup-tracker']='2.22.0'
)

expand_ansible_tags_on_upgrade() {
  if is_upgrade_mode_set; then
    debug "Upgrade mode detected, expading ansible tags."
    local installed_version=$(get_installed_version)
    debug "Upgrading ${installed_version} -> ${RELEASE_VERSION}"
    expand_ansible_tags_on_full_upgrade
    expand_ansible_tags_with_tune_tag
    expand_ansible_tags_with_upgrade_from_tags ${installed_version}
    expand_ansible_tags_with_role_tags ${installed_version}
    expand_ansible_tags_with_install_kctl_tools_tag ${installed_version}
    debug "ANSIBLE_TAGS is set to ${ANSIBLE_TAGS}"
  fi
}

expand_ansible_tags_on_full_upgrade() {
  if [[ "${ANSIBLE_TAGS}" =~ full-upgrade ]]; then
    ANSIBLE_TAGS="${ANSIBLE_TAGS},upgrade"
  fi
}

expand_ansible_tags_with_tune_tag() {
  if is_ram_size_mb_changed; then
    debug 'RAM size was changed recently, force tuning'
    ANSIBLE_TAGS="${ANSIBLE_TAGS},tune"
  fi
}

expand_ansible_tags_with_upgrade_from_tags() {
  local installed_version=${1}
  for checkpoint_version in "${UPGRADE_CHECKPOINTS[@]}"; do
    if need_to_expand_with_upgrade_from_tag ${installed_version} ${checkpoint_version}; then
      ANSIBLE_TAGS="${ANSIBLE_TAGS},upgrade-from-${checkpoint_version}"
    fi
  done
}

expand_ansible_tags_with_role_tags() {
  local installed_version=${1}
  for role_tag in ${!REPLAY_ROLE_TAGS_SINCE[@]}; do
    replay_role_tag_since=${REPLAY_ROLE_TAGS_SINCE[${role_tag}]}
    if (( $(as_version ${installed_version}) <= $(as_version ${replay_role_tag_since}) )); then
      ANSIBLE_TAGS="${ANSIBLE_TAGS},${role_tag}"
    fi
  done
}

expand_ansible_tags_with_install_kctl_tools_tag() {
  local installed_version=${1}
  if (( $(as_version ${installed_version}) < $(as_version ${RELEASE_VERSION}) )); then
    ANSIBLE_TAGS="${ANSIBLE_TAGS},install-kctl-tools"
  fi
}

get_installed_version() {
  if [[ "${ANSIBLE_TAGS}" =~ full-upgrade ]]; then
    debug "ANSIBLE_TAGS contains full-upgrade, simulating upgrade from ${VERY_FIRST_VERSION}"
    echo ${VERY_FIRST_VERSION}
  else
    echo ${INSTALLED_VERSION}
  fi
}

need_to_expand_with_upgrade_from_tag() {
  local installed_version=${1}
  local checkpoint_version=${2}
  local checkpoint_minor_version="$(as_minor_version ${checkpoint_version})"
  local installed_minor_version="$(as_minor_version ${installed_version})"
  local current_installer_minor_version="$(as_minor_version ${RELEASE_VERSION})"
  (( ${checkpoint_minor_version} > ${installed_minor_version} )) || \
  ( \
    [[ ${checkpoint_minor_version} == ${installed_minor_version} ]] && \
      (( ${checkpoint_minor_version} < ${current_installer_minor_version} )) \
  )
}

is_upgrade_mode_set() {
  [[ "${ANSIBLE_TAGS}" =~ upgrade  ]]
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
  if isset "$RECONFIGURE"; then
    assert_config_relevant_or_upgrade_running
    write_inventory_on_reconfiguration
    expand_ansible_tags_on_upgrade
  else
    assert_keitaro_not_installed
    stage4                  # get and save vars to the inventory file
  fi
  ensure_license_valid
  stage5                    # upgrade packages and install ansible
  stage6                    # upgrade packages and run ansible playbook
}

install "$@"
