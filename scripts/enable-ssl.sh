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

values () 
{ 
    echo "$2"
}




PROGRAM_NAME='enable-ssl'


KEITARO_URL="https://keitarotds.com"

SCRIPT_NAME="${PROGRAM_NAME}.sh"
SCRIPT_URL="${KEITARO_URL}/${PROGRAM_NAME}.sh"
SCRIPT_LOG="${PROGRAM_NAME}.log"

if [[ "${SHELLNAME}" == 'bash' ]]; then
  if ! empty ${@}; then
    SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" | bash -s -- ${@}"
  else
    SCRIPT_COMMAND="curl -sSL "$SCRIPT_URL" | bash"
  fi
else
  if ! empty ${@}; then
    SCRIPT_COMMAND="${SHELLNAME} ${@}"
  else
    SCRIPT_COMMAND="${SHELLNAME}"
  fi
fi

declare -A VARS


declare -A DICT

DICT['en.errors.failure']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You must run this program as root.'
DICT['en.errors.run_command.fail']='There was an error evaluating command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.messages.run_command']='Evaluating command'
DICT['en.messages.successful']='Everything done!'
DICT['en.no']='no'
DICT['en.prompt_errors.validate_presence']='Please enter value'
DICT['en.prompt_errors.validate_yes_no']='Please answer "yes" or "no"'

DICT['ru.errors.failure']='ОШИБКА ВЫПОЛНЕНИЯ ПРОГРАММЫ'
DICT['ru.errors.must_be_root']='Эту программу может запускать только root.'
DICT['ru.errors.run_command.fail']='Ошибка выполнения команды'
DICT['ru.errors.run_command.fail_extra']=''
DICT['ru.errors.terminated']='Выполнение прервано'
DICT['ru.messages.run_command']='Выполняется команда'
DICT['ru.messages.successful']='Программа успешно завершена!'
DICT['ru.no']='нет'
DICT['ru.prompt_errors.validate_presence']='Введите значение'
DICT['ru.prompt_errors.validate_yes_no']='Ответьте "да" или "нет" (можно также ответить "yes" или "no")'


declare -a DOMAINS
NGINX_ROOT_PATH="/etc/nginx"
NGINX_VHOSTS_CONF="${NGINX_ROOT_PATH}/conf.d/vhosts.conf"
WEBROOT_PATH="/var/www/keitaro"


RECONFIGURE_COMMAND="curl ${KEITARO_URL}/install.sh | bash -s -- -t ssl"

DICT['en.errors.reinstall_keitaro_ssl']="Nginx settings of your Keitaro TDS installation does not properly configured. Please reconfigure Nginx by evaluating command '${RECONFIGURE_COMMAND}'"
DICT['en.errors.run_command.fail_extra']="Evaluating log saved to ${SCRIPT_LOG}. Please rerun '${SCRIPT_COMMAND}' after resolving installation problems."
DICT['en.prompts.ssl_agree_tos']="Do you agree with terms of Let's Encrypt Subscriber Agreement?"
DICT['en.prompts.ssl_agree_tos.help']="In order to install Let's Encrypt Free SSL certificates for your Keitaro TDS you must agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)."
DICT['en.prompts.ssl_email']='Please enter your email (you can left this field empty)'
DICT['en.prompts.ssl_email.help']='You can obtain SSL certificate with no email address. This is strongly discouraged, because in the event of key loss or LetsEncrypt account compromise you will irrevocably lose access to your LetsEncrypt account. You will also be unable to receive notice about impending expiration or revocation of your certificates.'

DICT['ru.errors.reinstall_keitaro_ssl']="Настройки Nginx вашей Keitaro TDS отконфигурированы неправильно. Пожалуйста выполните перенастройку Nginx выполнив команду '${RECONFIGURE_COMMAND}'"
DICT['ru.errors.run_command.fail_extra']="Журнал выполнения сохранён в ${SCRIPT_LOG}. Пожалуйста запустите '${SCRIPT_COMMAND}' после устранения возникших проблем."
DICT['ru.prompts.ssl_agree_tos']="Вы согласны с условиями Абонентского Соглашения Let's Encrypt?"
DICT['ru.prompts.ssl.agrre_tos.help']="Для получения бесплатных SSL сертификатов Let's Encrypt вы должны согласиться с условиями Абонентского Соглашения Let's Encrypt (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)."
DICT['ru.prompts.ssl_email']='Укажите email (можно не указывать)'
DICT['ru.prompts.ssl_email.help']='Вы можете получить SSL сертификат без указания email адреса. Однако LetsEncrypt настоятельно рекомендует указать его, так как в случае потери ключа или компрометации LetsEncrypt аккаунта вы полностью потеряете доступ к своему LetsEncrypt аккаунту. Без email вы также не сможете получить уведомление о предстоящем истечении срока действия или отзыве сертификата'



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



is_installed(){
  local command="${1}"
  debug "Try to found "$command""
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual checking of '$command' presence"
  else
    if [[ $(sh -c "command -v "$command" -gt /dev/null") ]]; then
      debug "OK: "$command" found"
    else
      debug "NOK: "$command" not found"
      return 1
    fi
  fi
}



get_user_var(){
  local var_name="${1}"
  local validation_method="${2}"
  print_prompt_help "$var_name"
  while true; do
    print_prompt "$var_name"
    variable=$(read_stdin "$var_name")
    if ! empty "$variable"; then
      VARS[$var_name]=$variable
    fi
    if is_valid "$validation_method" "${VARS[$var_name]}"; then
      debug "  "$var_name"="$variable"" 'light.blue'
      break
    else
      VARS[$var_name]=''
      print_prompt_error "$validation_method"
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




is_pipe_mode(){
  [ "${SHELLNAME}" == 'bash' ]
}



print_prompt(){
  local var_name="${1}"
  prompt=$(translate "prompts.$var_name")
  prompt="$(print_with_color "$prompt" 'bold')"
  if ! empty ${VARS[$var_name]}; then
    prompt="$prompt [${VARS[$var_name]}]"
  fi
  echo -en "$prompt > "
}


print_prompt_error(){
  local error_key="${1}"
  error=$(translate "prompt_errors.$error_key")
  print_with_color "*** ${error}" 'red'
}





print_prompt_help(){
  local var_name="${1}"
  print_translated "prompts.$var_name.help"
}



read_stdin(){
  local var_name="${1}"
  if is_pipe_mode; then
    read -r -u 3 variable
  else
    read -r variable
  fi
  echo "$variable"
}


is_valid(){
  local validation_method="${1}"
  local value="${2}"
  if empty "$validation_method"; then
    true
  else
    eval "$validation_method" "$value"
  fi
}


validate_presence(){
  local value="${1}"
  isset "$value"
}


validate_yes_no(){
  local value="${1}"
  (is_yes_answer "$value" || is_no_answer "$value")
}


is_yes_answer(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(yes|y|да|д) ]]
}


is_no_answer(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(no|n|нет|н) ]]
}


is_yes_answer(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(yes|y|да|д) ]]
}


is_no_answer(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(no|n|нет|н) ]]
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
  log_and_print_err "*** $(translate errors.failure) ***"
  log_and_print_err "$message"
  print_err
  clean_up
  exit 1
}


log_and_print_err(){
  local message="${1}"
  print_err "$message" 'red'
  debug "$message" 'red'
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
  debug "Evaluating command: ${command}"
  run_command_message=$(print_with_color "$(translate 'messages.run_command')" 'blue')
  echo -e "$run_command_message '$command'"
  if isset "$PRESERVE"; then
    debug "Actual running disabled"
  else
    evaluated_command="(set -o pipefail && (${command}) 2>&1 | tee -a ${SCRIPT_LOG})"
    debug "Real command: ${evaluated_command}"
    if ! eval "${evaluated_command}"; then
      message="$(translate 'errors.run_command.fail') '$command'\n$(translate 'errors.run_command.fail_extra')"
      fail "$message"
    fi
  fi
}



stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  set_ui_lang
}



parse_options(){
  while getopts ":hpsl:" opt; do
    case $opt in
      p)
        PRESERVE=true
        ;;
      s)
        SKIP_CHECKS=true
        ;;
      l)
        case $OPTARG in
          en)
            UI_LANG=en
            ;;
          ru)
            UI_LANG=ru
            ;;
          *)
            print_err "Specified language \"$OPTARG\" is not supported"
            exit 1
            ;;
        esac
        ;;
      :)
        print_err "Option -$OPTARG requires an argument."
        exit 1
        ;;
      h)
        usage
        exit 0
        ;;
      \?)
        usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND-1))
  if [[ ${#} == 0 ]]; then
    usage
    exit 1
  else
    while [[ ${#} -gt 0 ]]; do
      if [[ ! "${1}" =~ ^(-) ]]; then
        DOMAINS+=("${1}")
      fi
      shift
    done
  fi
}


usage(){
  set_ui_lang
  if [[ "$UI_LANG" = 'ru' ]]; then
    ru_usage
  else
    en_usage
  fi
}


ru_usage(){
  print_err "$SCRIPT_NAME подключает SSL сертификат от Let's Encrypt для указанных доменов Keitaro TDS"
  print_err
  print_err "Использование: "$SCRIPT_NAME" [-ps] [-l en|ru] domain1.tld [domain2.tld] ..."
  print_err
  print_err "  -p"
  print_err "    С опцией -p (preserve commands running) "$SCRIPT_NAME" не выполняет установочные команды. Вместо этого текст команд будет показан на экране."
  print_err
  print_err "  -s"
  print_err "    С опцией -s (skip checks) "$SCRIPT_NAME" не будет проверять присутствие нужных программ в системе, не будет проверять факт запуска из под root."
  print_err
  print_err "  -l <lang>"
  print_err "    "$SCRIPT_NAME" определяет язык через установленные переменные окружения LANG/LC_MESSAGES/LC_ALL, однако язык может быть явно задан помощи параметра -l."
  print_err "    На данный момент поддерживаются значения en и ru (для английского и русского языков)."
  print_err
}


en_usage(){
  print_err "$SCRIPT_NAME generates Let's Encrypt SSL for the specified domains of Keitaro TDS"
  print_err
  print_err "Usage: "$SCRIPT_NAME" [-ps] [-l en|ru] domain1.tld [domain2.tld] ..."
  print_err
  print_err "  -p"
  print_err "    The -p (preserve commands running) option causes "$SCRIPT_NAME" to preserve the invoking of installation commands. Installation commands will be printed to stdout instead."
  print_err
  print_err "  -s"
  print_err "    The -s (skip checks) option causes "$SCRIPT_NAME" to skip checks of required programs presence, skip check root running"
  print_err
  print_err "  -l <lang>"
  print_err "    By default "$SCRIPT_NAME" tries to detect language from LANG/LC_MESSAGES/LC_ALL environment variables, but language can be explicitly set  with -l option."
  print_err "    Only en and ru (for English and Russian) values supported now."
  print_err
}



stage2(){
  debug "Starting stage 2: make some asserts"
  assert_certbot_installed
  assert_nginx_configured
}



assert_caller_root(){
  debug 'Ensure script has been running by root'
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: actual checking of current user"
  else
    if [[ "$EUID" = 0 ]]; then
      debug 'OK: current user is root'
    else
      debug 'NOK: current user is not root'
      fail "$(translate errors.must_be_root)"
    fi
  fi
}


assert_certbot_installed(){
  if ! is_installed 'certbot'; then
    fail "$(translate 'errors.reinstall_keitaro_ssl')"
  fi
}


assert_nginx_configured(){
  if ! is_nginx_properly_configured; then
    fail "$(translate 'errors.reinstall_keitaro_ssl')"
  fi
}


is_nginx_properly_configured(){
  is_vhosts_conf_installed && is_ssl_configured
}

is_vhosts_conf_installed(){
  debug "Checking ${NGINX_VHOSTS_CONF} existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ${NGINX_VHOSTS_CONF} existence disabled"
    return 0
  fi
  if [ -f "${NGINX_VHOSTS_CONF}" ]; then
    debug "OK: ${NGINX_VHOSTS_CONF} exists"
    return 0
  else
    debug "NOK: ${NGINX_VHOSTS_CONF} does not exist"
    return 1
  fi
}


is_ssl_configured(){
  local ssl_root="${NGINX_ROOT_PATH}/ssl"
  debug "Checking ssl params in ${NGINX_VHOSTS_CONF}"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ssl params in ${NGINX_VHOSTS_CONF} disabled"
    return 0
  fi
  if grep -q -e "ssl_certificate #{ssl_root}/cert.pem;" -e "ssl_certificate_key ${ssl_root}/privkey.pem;" "${NGINX_VHOSTS_CONF}"; then
    debug "OK: it seems like ${NGINX_VHOSTS_CONF} is properly configured"
    return 0
  else
    debug "NOK: ${NGINX_VHOSTS_CONF} is not properly configured"
    return 1
  fi
}




stage3(){
  debug "Starting stage 3: get user vars"
  setup_vars
  get_user_vars
}



get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  get_user_var 'ssl_agree_tos' 'validate_yes_no'
  if is_yes_answer ${VARS['ssl_agree_tos']}; then
    echo $(is_yes_answer ${VARS['ssl_agree_tos']})
    get_user_var 'ssl_email'
  else
    fail "$(translate 'prompts.ssl_agree_tos.help')"
  fi
}



setup_vars(){
  VARS['ssl_agree_tos']=$(translate 'no')
}



stage4(){
  debug "Starting stage 3: run certbot"
  run_certbot
  make_cert_links
}



make_cert_links(){
  debug "make_cert_links"
}



run_certbot(){
  certbot_command="certbot certonly --webroot --webroot-path=${WEBROOT_PATH} --agree-tos --non-interactive --expand"
  for domain in "${DOMAINS[@]}"; do
    certbot_command="${certbot_command} --domain ${domain}"
  done
  if isset "$EMAIL"; then
    certbot_command="${certbot_command} --email ${EMAIL}"
  else
    certbot_command="${certbot_command} --register-unsafely-without-email"
  fi
  run_command "${certbot_command}"
  show_successful_message
}



show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
}



PROGRAM_NAME="enable-ssl"






enable_ssl(){
  init "$@"
  stage1 "$@"
  stage2
  stage3
  stage4
}


enable_ssl "$@"

# wait for all async child processes (because "await ... then" is used in powscript)
[[ $ASYNC == 1 ]] && wait


exit 0
