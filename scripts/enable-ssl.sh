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


SHELL_NAME=$(basename "$0")

KEITARO_URL="https://keitarotds.com"

WEBROOT_PATH="/var/www/keitaro"

NGINX_ROOT_PATH="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_ROOT_PATH}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/vhosts.conf"

SCRIPT_NAME="${PROGRAM_NAME}.sh"
SCRIPT_URL="${KEITARO_URL}/${PROGRAM_NAME}.sh"
SCRIPT_LOG="${PROGRAM_NAME}.log"

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


declare -a DOMAINS
NGINX_SSL_PATH="${NGINX_ROOT_PATH}/ssl"
NGINX_SSL_CERT_PATH="${NGINX_SSL_PATH}/cert.pem"
NGINX_SSL_PRIVKEY_PATH="${NGINX_SSL_PATH}/privkey.pem"


RECONFIGURE_KEITARO_SSL_COMMAND_EN="curl -sSL ${KEITARO_URL}/install.sh | bash -s -- -l en -t nginx,ssl"

RECONFIGURE_KEITARO_SSL_COMMAND_RU="curl -sSL ${KEITARO_URL}/install.sh | bash -s -- -l ru -t nginx,ssl"

DICT['en.errors.reinstall_keitaro']="Your Keitaro TDS installation does not properly configured. Please reconfigure Keitaro TDS by evaluating command \`${RECONFIGURE_KEITARO_COMMAND_EN}\`"
DICT['en.errors.reinstall_keitaro_ssl']="Nginx settings of your Keitaro TDS installation does not properly configured. Please reconfigure Nginx by evaluating command \`${RECONFIGURE_KEITARO_SSL_COMMAND_EN}\`"
DICT['en.errors.see_logs']="Evaluating log saved to ${SCRIPT_LOG}. Please rerun \`${SCRIPT_COMMAND}\` after resolving problems."
DICT['en.messages.check_renewal_job']="Check that renewal job scheduled"
DICT['en.messages.make_ssl_cert_links']="Make SSL certificate links"
DICT['en.messages.renewal_job_already_scheduled']="Renewal job already scheduled"
DICT['en.messages.schedule_renewal_job']="Schedule renewal SSL certificate cron job"
DICT['en.messages.ssl_enabled_for_sites']="SSL certificates enabled for sites:"
DICT['en.prompts.ssl_agree_tos']="Do you agree with terms of Let's Encrypt Subscriber Agreement?"
DICT['en.prompts.ssl_agree_tos.help']=$(cat <<- END
	Make sure all the domains are already linked to this server in the DNS
	In order to install Let's Encrypt Free SSL certificates for your Keitaro TDS you must agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf).
END
)
DICT['en.prompts.ssl_email']='Please enter your email (you can left this field empty)'
DICT['en.prompts.ssl_email.help']='You can obtain SSL certificate with no email address. This is strongly discouraged, because in the event of key loss or LetsEncrypt account compromise you will irrevocably lose access to your LetsEncrypt account. You will also be unable to receive notice about impending expiration or revocation of your certificates.'

DICT['ru.errors.reinstall_keitaro']="Keitaro TDS отконфигурирована неправильно. Пожалуйста выполните перенастройку Keitaro TDS выполнив команду \`${RECONFIGURE_KEITARO_COMMAND_RU}\`"
DICT['ru.errors.reinstall_keitaro_ssl']="Настройки Nginx вашей Keitaro TDS отконфигурированы неправильно. Пожалуйста выполните перенастройку Nginx выполнив команду \`${RECONFIGURE_KEITARO_SSL_COMMAND_RU}\`"
DICT['ru.errors.see_logs']="Журнал выполнения сохранён в ${SCRIPT_LOG}. Пожалуйста запустите \`${SCRIPT_COMMAND}\` после устранения возникших проблем."
DICT['ru.messages.check_renewal_job']="Проверяем наличие cron задачи обновления сертификатов"
DICT['ru.messages.make_ssl_cert_links']="Создаются ссылки на SSL сертификаты"
DICT['ru.messages.renewal_job_already_scheduled']="Cron задача обновления сертификатов уже существует"
DICT['ru.messages.schedule_renewal_job']="Добавляется cron задача обновления сертификатов"
DICT['ru.messages.ssl_enabled_for_sites']="SSL сертификаты подключены для сайтов:"
DICT['ru.prompts.ssl_agree_tos']="Вы согласны с условиями Абонентского Соглашения Let's Encrypt?"
DICT['ru.prompts.ssl_agree_tos.help']=$(cat <<- END
	Убедитесь, что все указанные домены привязаны к этому серверу в DNS.
	Для получения бесплатных SSL сертификатов Let's Encrypt вы должны согласиться с условиями Абонентского Соглашения Let's Encrypt (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)."
END
)
DICT['ru.prompts.ssl_email']='Укажите email (можно не указывать)'
DICT['ru.prompts.ssl_email.help']='Вы можете получить SSL сертификат без указания email адреса. Однако LetsEncrypt настоятельно рекомендует указать его, так как в случае потери ключа или компрометации LetsEncrypt аккаунта вы полностью потеряете доступ к своему LetsEncrypt аккаунту. Без email вы также не сможете получить уведомление о предстоящем истечении срока действия или отзыве сертификата'



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



assert_installed(){
  local program="${1}"
  local error="${2}"
  if ! is_installed "$program"; then
    fail "$(translate ${error})" "see_logs"
  fi
}





is_exists_file(){
  local file="${1}"
  local result_on_skip="${2}"
  debug "Checking ${file} file existence"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ${file} file existence disabled"
    if [[ "$result_on_skip" == "no" ]]; then
      debug "NO: simulate ${file} file does not exist"
      return 1
    fi
    debug "YES: simulate ${file} file exists"
    return 0
  fi
  if [ -f "${file}" ]; then
    debug "YES: ${file} file exists"
    return 0
  else
    debug "NO: ${file} file does not exist"
    return 1
  fi
}



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
      debug "  ${var_name}=${value}" 'light.blue'
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




is_pipe_mode(){
  [ "${SHELL_NAME}" == 'bash' ]
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
  exit 1
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




reload_nginx(){
  debug "Reload nginx"
  run_command "nginx -s reload" "$(translate 'messages.reload_nginx')" 'hide_output'
}



run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
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
    if isset "$run_as"; then
      evaluated_command="sudo -u '${run_as}' bash -c '${command}'"
    else
      evaluated_command="${command}"
    fi
    if isset "$hide_output"; then
      evaluated_command="(set -o pipefail && (${evaluated_command}) >> ${SCRIPT_LOG} 2>&1)"
    else
      evaluated_command="(set -o pipefail && (${evaluated_command}) 2>&1 | tee -a ${SCRIPT_LOG})"
    fi
    debug "Real command: ${evaluated_command}"
    if ! eval "${evaluated_command}"; then
      print_command_status "$command" 'NOK' 'red' "$hide_output"
      if isset "$allow_errors"; then
        return 1 # false
      else
        fail "$(translate 'errors.run_command.fail') \`$command\`" "see_logs"
      fi
    else
      print_command_status "$command" 'OK' 'green' "$hide_output"
    fi
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



validate_presence(){
  local value="${1}"
  isset "$value"
}



is_no(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(no|n|нет|н) ]]
}



is_yes(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(yes|y|да|д) ]]
}


validate_yes_no(){
  local value="${1}"
  (is_yes "$value" || is_no "$value")
}



stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  set_ui_lang
}



parse_options(){
  while getopts ":hpsl:ae:w" opt; do
    case $opt in
      p)
        PRESERVE_RUNNING=true
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
      a)
        SKIP_SSL_AGREE_TOS=true
        ;;
      e)
        EMAIL="${OPTARG}"
        ;;
      w)
        SKIP_SSL_EMAIL=true
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
  print_err "Использование: "$SCRIPT_NAME" [-ps] [-l en|ru] [-e some.email@example.org] domain1.tld [domain2.tld] ..."
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
  print_err "  -e <email>"
  print_err "    Адрес электронной почты исползуемый для регистрации при получении бесплатных SSL сертификатов. Let's Encrypt"
  print_err
  print_err "  -w"
  print_err "    C опцией -w (without email) "$SCRIPT_NAME" не будет запрашивать у пользователя адрес электронной почты."
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
  print_err "    Only en and ru (for English and Russian) values are supported now."
  print_err
  print_err "  -e <email>"
  print_err "    Email used for registration while getting Free SSL Let's Encrypt certificates."
  print_err
  print_err "  -w"
  print_err "    The -w (without email) option causes "$SCRIPT_NAME" to skip email request."
  print_err
}



stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_installed 'nginx' 'errors.reinstall_keitaro'
  assert_installed 'crontab' 'errors.reinstall_keitaro'
  assert_installed 'certbot' 'errors.reinstall_keitaro_ssl'
  assert_nginx_configured
}



assert_nginx_configured(){
  if ! is_nginx_properly_configured; then
    fail "$(translate 'errors.reinstall_keitaro_ssl')" "see_logs"
  fi
}


is_nginx_properly_configured(){
  is_exists_file "${NGINX_KEITARO_CONF}" &&
    is_exists_file "${NGINX_SSL_CERT_PATH}" &&
    is_exists_file "${NGINX_SSL_PRIVKEY_PATH}" &&
    is_ssl_configured
  }


is_ssl_configured(){
  debug "Checking ssl params in ${NGINX_KEITARO_CONF}"
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of ssl params in ${NGINX_KEITARO_CONF} disabled"
    return 0
  fi
  if grep -q -e "ssl_certificate #{NGINX_SSL_CERT_PATH};" -e "ssl_certificate_key ${NGINX_SSL_PRIVKEY_PATH};" "${NGINX_KEITARO_CONF}"; then
    debug "OK: it seems like ${NGINX_KEITARO_CONF} is properly configured"
    return 0
  else
    debug "NOK: ${NGINX_KEITARO_CONF} is not properly configured"
    debug $(print_content_of "$NGINX_KEITARO_CONF")
    return 1
  fi
}



stage3(){
  debug "Starting stage 3: get user vars"
  get_user_vars
}



get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  get_user_le_sa_agreement
  if is_yes ${VARS['ssl_agree_tos']}; then
    get_user_email
  else
    fail "$(translate 'prompts.ssl_agree_tos.help')"
  fi
}


get_user_le_sa_agreement(){
  if isset "$SKIP_SSL_AGREE_TOS"; then
    VARS['ssl_agree_tos']='yes'
    debug "Do not request SSL user agreement because appropriate option specified"
  else
    VARS['ssl_agree_tos']=$(translate 'no')
    get_user_var 'ssl_agree_tos' 'validate_yes_no'
  fi
}


get_user_email(){
  if isset "$SKIP_SSL_EMAIL"; then
    debug "Do not request SSL email because appropriate option specified"
  else
    if isset "$EMAIL"; then
      debug "Do not request SSL email because email specified by option"
      VARS['ssl_email']="${EMAIL}"
    else
      get_user_var 'ssl_email'
    fi
  fi
}



stage4(){
  debug "Starting stage 4: install LE certificates"
  run_certbot
  make_cert_links
  add_renewal_job
  reload_nginx
  show_successful_message
}



add_renewal_job(){
  debug "Add renewal certificates cron job"
  local renew_cmd="certbot renew --allow-subset-of-names --quiet"
  local cron_task_installed=false
  local check_renewal_job_cmd="crontab -l -u nginx | grep '${renew_cmd}'"
  if run_command "${check_renewal_job_cmd}" "$(translate 'messages.check_renewal_job')" "hide_output" "allow_errors"; then
    debug "Renewal cron job already exists"
    print_translated 'messages.renewal_job_already_scheduled'
  else
    debug "Renewal cron job does not exist. Adding renewal cron job"
    local hour="$(date +'%H')"
    local minute="$(date +'%M')"
    local renew_job="${minute} ${hour} * * * ${renew_cmd}"
    local schedule_renewal_job_cmd="(crontab -l -u nginx; echo \"${renew_job}\") | crontab -u nginx -"
    run_command "${schedule_renewal_job_cmd}" "$(translate 'messages.schedule_renewal_job')" "hide_output"
  fi
}



make_cert_links(){
  debug "Make certificate links"
  local le_cert_path="/etc/letsencrypt/live/${DOMAINS[0]}/fullchain.pem"
  local le_privkey_path="/etc/letsencrypt/live/${DOMAINS[0]}/privkey.pem"
  local command="rm -f ${NGINX_SSL_CERT_PATH} && rm -f ${NGINX_SSL_PRIVKEY_PATH}"
  command="${command} && ln -s ${le_cert_path} ${NGINX_SSL_CERT_PATH}"
  command="${command} && ln -s ${le_privkey_path} ${NGINX_SSL_PRIVKEY_PATH}"
  run_command "${command}" "$(translate 'messages.make_ssl_cert_links')" 'hide_output' '' 'nginx'
}



run_certbot(){
  debug "Run certbot"
  certbot_command="certbot certonly --webroot --webroot-path=${WEBROOT_PATH} --agree-tos --non-interactive --expand"
  for domain in "${DOMAINS[@]}"; do
    certbot_command="${certbot_command} --domain ${domain}"
  done
  if isset "${VARS['ssl_email']}"; then
    certbot_command="${certbot_command} --email ${VARS['ssl_email']}"
  else
    certbot_command="${certbot_command} --register-unsafely-without-email"
  fi
  run_command "${certbot_command}" '' '' '' 'nginx'
}



show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
  print_translated 'messages.ssl_enabled_for_sites'
  for domain in "${DOMAINS[@]}"; do
    print_with_color "https://${domain}/admin" 'green'
  done
}








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

