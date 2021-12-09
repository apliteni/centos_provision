#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

umask 22


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


TOOL_NAME='test-run-command'

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.29.18'
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
  SCRIPT_COMMAND="curl -fsSL $SCRIPT_URL | bash -s -- ${TOOL_ARGS}"
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
  IFS="=" read -r name value <<< "${substitution}"
  string="${string//:${name}:/${value}}"
  echo "${string}"
}

add_indentation(){
  sed -r "s/^/$INDENTATION_SPACES/g"
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

init() {
  init_kctl
  force_utf8_input
  debug "Starting init stage: log basic info"
  debug "Command: ${SCRIPT_COMMAND}"
  debug "Script version: ${RELEASE_VERSION}"
  debug "User ID: ${EUID}"
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGINT SIGTERM
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

ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^(fatal|failed): "
ANSIBLE_FAILURE_JSON_FILEPATH="${WORKING_DIR}/ansible_failure.json"
ANSIBLE_LAST_TASK_LOG="${WORKING_DIR}/ansible_last_task.log"

run_ansible_playbook(){
  local env=""
  env="${env} KCTL_BRANCH=${BRANCH}"
  env="${env} ANSIBLE_FORCE_COLOR=true"
  env="${env} ANSIBLE_CONFIG=${PLAYBOOK_DIRECTORY}/ansible.cfg"
  env="${env} WITHOUT_LICENSE_KEY=${VARS['without_key']}"
  env="${env} PROVISION_BIN_DIRECTORY=${PROVISION_BIN_DIRECTORY}"

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

show_credentials(){
  print_with_color "http://$(detected_license_ip)/admin" 'light.green'

  if isset "${VARS['db_restore_path']}"; then
    translate 'messages.successful.use_old_credentials'
  else
    if empty "${VARS['without_key']}" && isset "${VARS['admin_password']}"; then
      colored_login=$(print_with_color "${VARS['admin_login']}" 'light.green')
      colored_password=$(print_with_color "${VARS['admin_password']}" 'light.green')
      echo -e "login: ${colored_login}"
      echo -e "password: ${colored_password}"
    fi
  fi
}

show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
}


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html

test_run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local failed_logs_filter="${6}"
  UI_LANG=en
  init
  run_command "${command}" "${message}" "${hide_output}" "${allow_errors}" "${run_as}" "${failed_logs_filter}"
}


test_run_command "${1}" "${2}" "${3}" "${4}" "${5}" "${6}"
