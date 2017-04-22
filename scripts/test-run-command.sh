#!/usr/bin/env bash

# Generated by POWSCRIPT (https://github.com/coderofsalvation/powscript)

# Unless you like pain: edit the .pow sourcefiles instead of this file

# powscript general settings
set -e                                # halt on error
set +m                                
SHELL="$(echo $0)"                    # shellname
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions
path="$(pwd)"
if [[ "$BASH_SOURCE" == "$0"  ]];then 
  SHELLNAME="$(basename $SHELL)"      # shellname without path
  selfpath="$( dirname "$(readlink -f "$0")" )"
  tmpfile="/tmp/$(basename $0).tmp.$(whoami)"
else
  selfpath="$path"
  tmpfile="/tmp/.dot.tmp.$(whoami)"
fi

# generated by powscript (https://github.com/coderofsalvation/powscript)


empty () 
{ 
    [[ "${#1}" == 0 ]] && return 0 || return 1
}

isset () 
{ 
    [[ ! "${#1}" == 0 ]] && return 0 || return 1
}

last () 
{ 
    [[ ! -n $1 ]] && return 1;
    echo "$(eval "echo \${$1[@]:(-1)}")"
}




PROGRAM_NAME='test-run-command'


SHELL_NAME=$(basename "$0")

SUCCESS_RESULT=0
FAILURE_RESULT=1
ROOT_UID=0

KEITARO_URL="https://keitarotds.com"

WEBROOT_PATH="/var/www/keitaro"

NGINX_ROOT_PATH="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_ROOT_PATH}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/vhosts.conf"

SCRIPT_NAME="${PROGRAM_NAME}.sh"
SCRIPT_URL="${KEITARO_URL}/${PROGRAM_NAME}.sh"
SCRIPT_LOG="${PROGRAM_NAME}.log"

CURRENT_COMMAND_OUTPUT_LOG="current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="current_command.error.log"
CURRENT_COMMAND_SCRIPT="current_command.sh"

if [[ "${SHELL_NAME}" == 'bash' ]]; then
  if ! empty ${@}; then
    SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" | bash -s -- ${@}"
  else
    SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" | bash"
  fi
else
  if ! empty ${@}; then
    SCRIPT_COMMAND="${SHELL_NAME} ${@}"
  else
    SCRIPT_COMMAND="${SHELL_NAME}"
  fi
fi

declare -A VARS

RECONFIGURE_KEITARO_COMMAND_EN="curl -sSL ${KEITARO_URL}/install.sh | bash"

RECONFIGURE_KEITARO_COMMAND_RU="curl -sSL ${KEITARO_URL}/install.sh | bash -s -- -l ru"


declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You must run this program as root.'
DICT['en.errors.run_command.fail']='There was an error evaluating command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.messages.reload_nginx']="Reloading nginx"
DICT['en.messages.run_command']='Evaluating command'
DICT['en.messages.successful']='Everything done!'
DICT['en.no']='no'
DICT['en.prompt_errors.validate_domains_list']='Please enter domains list, separated by comma without spaces (i.e. domain1.tld,www.domain1.tld). Each domain name must consist of only letters, numbers and hyphens and contain at least one dot.'
DICT['en.prompt_errors.validate_presence']='Please enter value'
DICT['en.prompt_errors.validate_yes_no']='Please answer "yes" or "no"'

DICT['ru.errors.program_failed']='ОШИБКА ВЫПОЛНЕНИЯ ПРОГРАММЫ'
DICT['ru.errors.must_be_root']='Эту программу может запускать только root.'
DICT['ru.errors.run_command.fail']='Ошибка выполнения команды'
DICT['ru.errors.run_command.fail_extra']=''
DICT['ru.errors.terminated']='Выполнение прервано'
DICT['ru.messages.reload_nginx']="Перезагружается nginx"
DICT['ru.messages.run_command']='Выполняется команда'
DICT['ru.messages.successful']='Программа успешно завершена!'
DICT['ru.no']='нет'
DICT['ru.prompt_errors.validate_domains_list']='Укажите список доменных имён через запятую без пробелов (например domain1.tld,www.domain1.tld). Каждое доменное имя должно состоять только из букв, цифр и тире и содержать хотябы одну точку.'
DICT['ru.prompt_errors.validate_presence']='Введите значение'
DICT['ru.prompt_errors.validate_yes_no']='Ответьте "да" или "нет" (можно также ответить "yes" или "no")'



set_ui_lang(){
  if empty "$UI_LANG"; then
    UI_LANG=$(detect_language)
  fi
  debug "Language: ${UI_LANG}"
}


detect_language(){
  if ! empty "$LC_ALL"; then
    detect_language_from_var "$LC_ALL"
  else
    if ! empty "$LC_MESSAGES"; then
      detect_language_from_var "$LC_MESSAGES"
    else
      detect_language_from_var "$LANG"
    fi
  fi
}


detect_language_from_var(){
  local lang_value="${1}"
  if [[ "$lang_value" =~ ^ru_[[:alpha:]]+\.UTF-8$ ]]; then
    echo ru
  else
    echo en
  fi
}



translate(){
  local key="${1}"
  local i18n_key=$UI_LANG.$key
  if isset ${DICT[$i18n_key]}; then
    echo "${DICT[$i18n_key]}"
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



debug(){
  local message="${1}"
  local color="${2}"
  if empty "$color"; then
    color='light.green'
  fi
  print_with_color "$message" "$color" >> "$SCRIPT_LOG"
}



fail(){
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



init(){
  init_log
  debug "Starting init stage: log basic info"
  debug "Command: ${SCRIPT_COMMAND}"
  debug "User ID: "$EUID""
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGINT SIGTERM
}



init_log(){
  if [ -f ${SCRIPT_LOG} ]; then
    name_for_old_log=$(get_name_for_old_log ${SCRIPT_LOG})
    mv "$SCRIPT_LOG" "$name_for_old_log"
    debug "Old log ${SCRIPT_LOG} moved to "$name_for_old_log""
  else
    debug "${SCRIPT_LOG} created"
  fi
}

get_name_for_old_log(){
  local basename="${1}"
  old_suffix=0
  if [ -f ${basename}.1 ]; then
    old_suffix=$(ls ${basename}.* | grep -oP '\d+$' | sort | tail -1)
  fi
  current_suffix=$(expr "$old_suffix" + 1)
  echo "$basename".$current_suffix
}



log_and_print_err(){
  local message="${1}"
  print_err "$message" 'red'
  debug "$message" 'red'
}



on_exit(){
  debug "Terminated by user"
  echo
  clean_up
  remove_current_command
  fail "$(translate 'errors.terminated')"
}



print_content_of(){
  local filepath="${1}"
  if [ -f "$filepath" ]; then
    echo "Content of '${filepath}':\n$(cat "$filepath" | sed 's/^/  /g')"
  else
    echo "Can't show '${filepath}' content - file does not exist"
  fi
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




run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local print_fail_message_method="${6}"
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
    really_run_command "${command}" "${hide_output}" "${allow_errors}" "${run_as}" "${print_fail_message_method}"
  fi
}


print_command_status(){
  local command="${1}"
  local status="${2}"
  local color="${3}"
  local hide_output="${4}"
  debug "Command result: ${status}"
  if isset "$hide_output"; then
    print_with_color "$status" "$color"
  fi
}


really_run_command(){
  local command="${1}"
  local hide_output="${2}"
  local allow_errors="${3}"
  local run_as="${4}"
  local print_fail_message_method="${5}"
  save_command_script "${command}"
  local evaluated_command="./${CURRENT_COMMAND_SCRIPT}"
  evaluated_command=$(command_run_as "${evaluated_command}" "${run_as}")
  evaluated_command=$(unbuffer_streams "${evaluated_command}")
  evaluated_command=$(save_command_logs "${evaluated_command}")
  evaluated_command=$(hide_command_output "${evaluated_command}" "${hide_output}")
  debug "Real command: ${evaluated_command}"
  if ! eval "${evaluated_command}"; then
    print_command_status "${command}" 'NOK' 'red' "${hide_output}"
    if isset "$allow_errors"; then
      remove_current_command
      return ${FAILURE_RESULT}
    else
      fail_message="$(print_current_command_fail_message ${print_fail_message_method})"
      remove_current_command
      fail "${fail_message}" "see_logs"
    fi
  else
    print_command_status "$command" 'OK' 'green' "$hide_output"
    remove_current_command
  fi
}


command_run_as(){
  local command="${1}"
  local run_as="${2}"
  if isset "$run_as"; then
    echo "sudo -u '${run_as}' bash -c '${command}'"
  else
    echo "${command}"
  fi
}


unbuffer_streams(){
  local command="${1}"
  echo "stdbuf -i0 -o0 -e0 ${command}"
}


save_command_logs(){
  local evaluated_command="${1}"
  local output_log="${2}"
  local error_log="${3}"
  save_output_log="tee -i ${CURRENT_COMMAND_OUTPUT_LOG} | tee -ia ${SCRIPT_LOG}"
  save_error_log="tee -i ${CURRENT_COMMAND_ERROR_LOG} | tee -ia ${SCRIPT_LOG}"
  echo "((${evaluated_command}) 2> >(${save_error_log}) > >(${save_output_log}))"
}


remove_colors_from_file(){
  local file="${1}"
  debug "Removing colors from file ${file}"
  sed -r -e 's/\x1b\[([0-9]{1,3}(;[0-9]{1,3}){,2})?[mGK]//g' -i "$file"
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
  echo '#!/usr/bin/env bash' > "${CURRENT_COMMAND_SCRIPT}"
  echo 'set -o pipefail' >> "${CURRENT_COMMAND_SCRIPT}"
  echo -e "${command}" >> "${CURRENT_COMMAND_SCRIPT}"
  chmod a+x "${CURRENT_COMMAND_SCRIPT}"
  debug "$(print_content_of ${CURRENT_COMMAND_SCRIPT})"
}

print_current_command_fail_message(){
  local print_fail_message_method="${1}"
  remove_colors_from_file "${CURRENT_COMMAND_OUTPUT_LOG}"
  remove_colors_from_file "${CURRENT_COMMAND_ERROR_LOG}"
  if empty "$print_fail_message_method"; then
    print_fail_message_method="print_common_fail_message"
  fi
  fail_message=$(translate 'errors.run_command.fail')
  fail_message="${fail_message}\n$(eval ${print_fail_message_method})"
  echo -e "${fail_message}"
}


print_common_fail_message(){
  keep_tail "${CURRENT_COMMAND_OUTPUT_LOG}"
  keep_tail "${CURRENT_COMMAND_ERROR_LOG}"
  local fail_message="$(print_content_of ${CURRENT_COMMAND_SCRIPT})"
  fail_message="${fail_message}\n$(print_content_of ${CURRENT_COMMAND_OUTPUT_LOG})"
  fail_message="${fail_message}\n$(print_content_of ${CURRENT_COMMAND_ERROR_LOG})"
  echo "$fail_message"
}


keep_tail(){
  local file="${1}"
  MAX_LINES_COUNT=20
  if [[ $(cat "${file}" | wc -l) -gt "$MAX_LINES_COUNT" ]]; then
    debug "${file} is too big, keep only ${MAX_LINES_COUNT} tail lines"
    tail -n "$MAX_LINES_COUNT" "$file" > "$file".tail
    mv "$file".tail "$file"
  fi
}



remove_current_command(){
  debug "Removing current_command script and logs"
  rm -f ${CURRENT_COMMAND_OUTPUT_LOG} ${CURRENT_COMMAND_ERROR_LOG} ${CURRENT_COMMAND_SCRIPT}
}


ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^fatal: "
ANSIBLE_FAILURE_JSON_FILEPATH="ansible_failure.json"

run_ansible_playbook(){
  local command="ANSIBLE_FORCE_COLOR=true ansible-playbook -vvv -i ${INVENTORY_FILE} ${PROVISION_DIRECTORY}/playbook.yml"
  if isset "$ANSIBLE_TAGS"; then
    command="${command} --tags ${ANSIBLE_TAGS}"
  fi
  if isset "$ANSIBLE_IGNORE_TAGS"; then
    command="${command} --skip-tags ${ANSIBLE_IGNORE_TAGS}"
  fi
  run_command "${command}" '' '' '' '' 'print_ansible_fail_message'
}


print_ansible_fail_message(){
  if ansible_task_found "$CURRENT_COMMAND_OUTPUT_LOG"; then
    debug "Found last ansible task"
    remove_text_before_last_pattern_occurence "$ANSIBLE_TASK_HEADER" "$CURRENT_COMMAND_OUTPUT_LOG"
    print_ansible_task_info "$CURRENT_COMMAND_OUTPUT_LOG"
    print_ansible_task_stdout_and_stderr "$CURRENT_COMMAND_OUTPUT_LOG"
  else
    print_common_fail_message
  fi
}

ansible_task_found(){
  local task_output_filepath="${1}"
  grep -qE "$ANSIBLE_TASK_HEADER" "$task_output_filepath"
}


print_ansible_task_info(){
  local task_output_filepath="${1}"
  task=$(head -n1 "$task_output_filepath" | sed -r "s/${ANSIBLE_TASK_HEADER}/\1/g")
  echo "Ansible failed task: '${task}'"
  task_path=$(head -n2 "$task_output_filepath" | tail -n1)
  if [[ "$task_path" =~ ^(task path:) ]]; then
    echo "Ansible failed ${task_path}"
  fi
}


print_ansible_task_stdout_and_stderr(){
  local task_output_filepath="${1}"
  if ansible_task_failure_found; then
    debug "Found last ansible failure"
    cp "$task_output_filepath" "$ANSIBLE_FAILURE_JSON_FILEPATH"
    keep_json_only "$ANSIBLE_FAILURE_JSON_FILEPATH"
    print_ansible_task_stdout_and_stderr_from_json "$ANSIBLE_FAILURE_JSON_FILEPATH"
    rm "$ANSIBLE_FAILURE_JSON_FILEPATH"
  fi
}


ansible_task_failure_found(){
  grep -q "$ANSIBLE_TASK_FAILURE_HEADER" "$CURRENT_COMMAND_OUTPUT_LOG"
}


keep_json_only(){
  local task_output_with_json="${1}"
  # The json with error is inbuilt into text. The structure of text is about:
  
  # TASK [$ROLE_NAME : "$TASK_NAME"] *******
  # task path: /path/to/task/file.yml:$LINE
  # .....
  # fatal: [localhost]: FAILED! => {
  #     .....
  #     failure JSON
  #     .....
  # }
  # .....
  
  # So remove all before "fatal: [localhost]: FAILED! => {" line
  sed -n -i -r "/${ANSIBLE_TASK_FAILURE_HEADER}/,\$p" "$task_output_with_json"
  # Replace first line to just '{'
  sed -i '1c{' "$task_output_with_json"
  # Remove all after '}'
  sed -i -e '/^}$/q' "$task_output_with_json"
}


remove_text_before_last_pattern_occurence(){
  local pattern="${1}"
  local file="${2}"
  sed -n -i -r "H;/${pattern}/h;\${g;p;}" "$file"
}


print_ansible_task_stdout_and_stderr_from_json(){
  local json_filepath="${1}"
  declare -A   fail_json
  eval "fail_json=$(cat "$ANSIBLE_FAILURE_JSON_FILEPATH" | json2dict)"
  echo "Task stderr: ${fail_json['stderr']}"
  echo "Task stdout: ${fail_json['stdout']}"
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



test_run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local failed_logs_filter="${6}"
  UI_LANG=en
  run_command "${command}" "${message}" "${hide_output}" "${allow_errors}" "${run_as}" "${failed_logs_filter}"
}


test_run_command "${1}" "${2}" "${3}" "${4}" "${5}" "${6}"

# wait for all async child processes (because "await ... then" is used in powscript)
[[ $ASYNC == 1 ]] && wait


exit 0

