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

on () 
{ 
    func="$1";
    shift;
    for sig in "$@";
    do
        trap "$func $sig" "$sig";
    done
}

values () 
{ 
    echo "$2"
}




PROGRAM_NAME='install'


SHELL_NAME=$(basename "$0")

KEITARO_URL="https://keitarotds.com"

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
    fail "$(translate ${error})"
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



get_user_var(){
  local var_name="${1}"
  local validation_method="${2}"
  print_prompt_help "$var_name"
  while true; do
    print_prompt "$var_name"
    variable="$(read_stdin)"
    if ! empty "$variable"; then
      VARS[$var_name]="${variable}"
    fi
    if is_valid "$validation_method" "${VARS[$var_name]}"; then
      debug "  ${var_name}=${variable}" 'light.blue'
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



install_package(){
  local package="${1}"
  run_command "yum install -y "$package""
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



on_exit(){
  echo
  clean_up
  fail "$(translate 'errors.terminated')"
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
  debug "Evaluating command: ${command}"
  if empty "$message"; then
    run_command_message=$(print_with_color "$(translate 'messages.run_command')" 'blue')
    message="$run_command_message '$command'"
  else
    message=$(print_with_color "${message}" 'blue')
  fi
  echo -en "${message} . "
  if isset "$PRESERVE_RUNNING"; then
    debug "Actual running disabled"
    print_with_color 'SKIPPED' 'yellow'
  else
    evaluated_command="(set -o pipefail && (${command}) 2>&1 | tee -a ${SCRIPT_LOG})"
    debug "Real command: ${evaluated_command}"
    if ! eval "${evaluated_command}"; then
      print_with_color 'NOK' 'red'
      message="$(translate 'errors.run_command.fail') '$command'\n$(translate 'errors.run_command.fail_extra')"
      fail "$message"
    else
      print_with_color 'OK' 'green'
    fi
  fi
}


INVENTORY_FILE=hosts.txt
PROVISION_DIRECTORY=centos_provision-master



DICT['en.errors.run_command.fail_extra']=$(cat <<- END
	Installation log saved to ${SCRIPT_LOG}. Configuration settings saved to ${INVENTORY_FILE}.
	You can rerun '${SCRIPT_COMMAND}' with saved settings after resolving installation problems.
END
)
DICT['en.errors.yum_not_installed']='This installer works only on yum-based systems. Please run this programm in CentOS/RHEL/Fedora distro'
DICT['en.prompts.admin_login']='Please enter keitaro admin login'
DICT['en.prompts.admin_password']='Please enter keitaro admin password'
DICT['en.prompts.db_name']='Please enter database name'
DICT['en.prompts.db_password']='Please enter database user password'
DICT['en.prompts.db_user']='Please enter database user name'
DICT['en.prompts.license_ip']='Please enter server IP'
DICT['en.prompts.license_ip']='Please enter server IP'
DICT['en.prompts.license_key']='Please enter license key'
DICT['en.prompts.ssl']="Do you want to install Free SSL certificates from Let's Encrypt?"
DICT['en.prompts.ssl.help']=$(cat <<- END
	Installer can install Free SSL certificates from Let's Encrypt. In order to install this certificates you must:
	1. Agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf).
	2. Have at least one domain associated with this server.
END
)
DICT['en.prompts.ssl_agree_tos']="Do you agree with terms of Let's Encrypt Subscriber Agreement?"
DICT['en.prompts.ssl_agree_tos.help']="Let's Encrypt Subscriber Agreement located at https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf."
DICT['en.prompts.ssl_domains']='Please enter server domains, separated by comma without spaces (i.e. domain1.tld,domain2.tld)'
DICT['en.prompts.ssl_email']='Please enter your email (you can left this field empty)'
DICT['en.prompts.ssl_email.help']='You can obtain SSL certificate with no email address. This is strongly discouraged, because in the event of key loss or LetsEncrypt account compromise you will irrevocably lose access to your LetsEncrypt account. You will also be unable to receive notice about impending expiration or revocation of your certificates.'
DICT['en.welcome']=$(cat <<- END
	Welcome to Keitaro TDS installer.
	This installer will guide you through the steps required to install Keitaro TDS on your server.
END
)

DICT['ru.errors.run_command.fail_extra']=$(cat <<- END
	Журнал установки сохранён в ${SCRIPT_LOG}. Настройки сохранены в ${INVENTORY_FILE}.
	Вы можете повторно запустить '${SCRIPT_COMMAND}' с этими настройками после устранения возникших проблем.
END
)
DICT['ru.errors.yum_not_installed']='Утановщик keitaro работает только с пакетным менеджером yum. Пожалуйста, запустите эту программу в CentOS/RHEL/Fedora дистрибутиве'
DICT['ru.prompts.admin_login']='Укажите имя администратора keitaro'
DICT['ru.prompts.admin_password']='Укажите пароль администратора keitaro'
DICT['ru.prompts.db_name']='Укажите имя базы данных'
DICT['ru.prompts.db_password']='Укажите пароль пользователя базы данных'
DICT['ru.prompts.db_user']='Укажите пользователя базы данных'
DICT['ru.prompts.license_ip']='Укажите IP адрес сервера'
DICT['ru.prompts.license_key']='Укажите лицензионный ключ'
DICT['ru.prompts.ssl']="Вы хотите установить бесплатные SSL сертификаты, предоставляемые Let's Encrypt?"
DICT['ru.prompts.ssl.help']=$(cat <<- END
	Программа установки может установить бесплатные SSL сертификаты, предоставляемые Let's Encrypt. Для этого вы должны:
	1. Согласиться с условиями Абонентского Соглашения Let's Encrypt (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf).
	2. Иметь хотя бы один домен для этого сервера.
END
)
DICT['ru.prompts.ssl_agree_tos']="Вы согласны с условиями Абонентского Соглашения Let's Encrypt?"
DICT['ru.prompts.ssl_agree_tos.help']="Абонентское Соглашение Let's Encrypt находится по адресу https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf."
DICT['ru.prompts.ssl_domains']='Укажите список доменов через запятую без пробелов (наример domain1.tld,domain2.tld)'
DICT['ru.prompts.ssl_email']='Укажите email (можно не указывать)'
DICT['ru.prompts.ssl_email.help']='Вы можете получить SSL сертификат без указания email адреса. Однако LetsEncrypt настоятельно рекомендует указать его, так как в случае потери ключа или компрометации LetsEncrypt аккаунта вы полностью потеряете доступ к своему LetsEncrypt аккаунту. Без email вы также не сможете получить уведомление о предстоящем истечении срока действия или отзыве сертификата'
DICT['ru.welcome']=$(cat <<- END
	Добро пожаловать в программу установки Keitaro TDS.
	Эта программа поможет собрать информацию необходимую для установки Keitaro TDS на вашем сервере.
END
)



clean_up(){
  if [ -d "$PROVISION_DIRECTORY" ]; then
    debug "Remove ${PROVISION_DIRECTORY}"
    rm -rf "$PROVISION_DIRECTORY"
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
}


usage(){
  set_ui_lang
  if [[ "$UI_LANG" == 'ru' ]]; then
    ru_usage
  else
    en_usage
  fi
}


ru_usage(){
  print_err "$SCRIPT_NAME устанавливает Keitaro TDS"
  print_err
  print_err "Использование: "$SCRIPT_NAME" [-ps] [-l en|ru]"
  print_err
  print_err "  -p"
  print_err "    С опцией -p (preserve installation) "$SCRIPT_NAME" не запускает установочные команды. Вместо этого текс команд будет показан на экране."
  print_err
  print_err "  -s"
  print_err "    С опцией -s (skip checks) "$SCRIPT_NAME" не будет проверять присутствие yum/ansible в системе, не будет проверять факт запуска из под root."
  print_err
  print_err "  -l <lang>"
  print_err "    "$SCRIPT_NAME" определяет язык через установленные переменные окружения LANG/LC_MESSAGES/LC_ALL, однако вы можете явно задать язык при помощи параметра -l."
  print_err "    На данный момент поддерживаются значения en и ru (для английского и русского языков)."
  print_err
}


en_usage(){
  print_err "$SCRIPT_NAME installs Keitaro TDS"
  print_err
  print_err "Usage: "$SCRIPT_NAME" [-ps] [-l en|ru]"
  print_err
  print_err "  -p"
  print_err "    The -p (preserve installation) option causes "$SCRIPT_NAME" to preserve the invoking of installation commands. Installation commands will be printed to stdout instead."
  print_err
  print_err "  -s"
  print_err "    The -s (skip checks) option causes "$SCRIPT_NAME" to skip checks of yum/ansible presence, skip check root running"
  print_err
  print_err "  -l <lang>"
  print_err "    By default "$SCRIPT_NAME" tries to detect language from LANG/LC_MESSAGES/LC_ALL environment variables, but you can explicitly set language with -l option."
  print_err "    Only en and ru (for English and Russian) values supported now."
  print_err
}



stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_installed 'yum' 'errors.yum_not_installed'
}





stage3(){
  debug "Starting stage 3: generate inventory file"
  setup_vars
  read_inventory_file
  get_user_vars
  write_inventory_file
}



get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  print_translated "welcome"
  get_user_ssl_vars
  get_user_var 'license_ip' 'validate_presence'
  get_user_var 'license_key' 'validate_presence'
  get_user_var 'db_name' 'validate_presence'
  get_user_var 'db_user' 'validate_presence'
  get_user_var 'db_password' 'validate_presence'
  get_user_var 'admin_login' 'validate_presence'
  get_user_var 'admin_password' 'validate_presence'
}


get_user_ssl_vars(){
  VARS['ssl_certificate']='self-signed'
  get_user_var 'ssl' 'validate_yes_no'
  if is_yes_answer ${VARS['ssl']}; then
    get_user_var 'ssl_agree_tos' 'validate_yes_no'
    if is_yes_answer ${VARS['ssl_agree_tos']}; then
      VARS['ssl_certificate']='letsencrypt'
      get_user_var 'ssl_domains' 'validate_presence'
      get_user_var 'ssl_email'
    fi
  fi
}



read_inventory_file(){
  if [ -f "$INVENTORY_FILE" ]; then
    debug "Inventory file found, read defaults from it"
    while IFS="" read -r line; do
      parse_line_from_inventory_file "$line"
    done <   $INVENTORY_FILE
  else
    debug "Inventory file not found"
  fi
}


parse_line_from_inventory_file(){
  local line="${1}"
  if [[ "$line" =~ = ]]; then
    IFS="=" read var_name value <<< "$line"
    VARS[$var_name]=$value
    debug "  "$var_name"=${VARS[$var_name]}" 'light.blue'
  fi
}



setup_vars(){
  VARS['ssl']=$(translate 'no')
  VARS['ssl_agree_tos']=$(translate 'no')
  VARS['db_name']='keitaro'
  VARS['db_user']='keitaro'
  VARS['db_password']=$(generate_password)
  VARS['admin_login']='admin'
  VARS['admin_password']=$(generate_password)
}


generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}



write_inventory_file(){
  debug "Write inventory file"
  echo -n > "$INVENTORY_FILE"
  print_line_to_inventory_file "[server]"
  print_line_to_inventory_file "localhost connection=local"
  print_line_to_inventory_file
  print_line_to_inventory_file "[server:vars]"
  print_line_to_inventory_file "ssl="${VARS['ssl']}""
  print_line_to_inventory_file "ssl_certificate="${VARS['ssl_certificate']}""
  print_line_to_inventory_file "ssl_agree_tos="${VARS['ssl_agree_tos']}""
  print_line_to_inventory_file "ssl_domains="${VARS['ssl_domains']}""
  print_line_to_inventory_file "ssl_email="${VARS['ssl_email']}""
  print_line_to_inventory_file "license_ip="${VARS['license_ip']}""
  print_line_to_inventory_file "license_key="${VARS['license_key']}""
  print_line_to_inventory_file "db_name="${VARS['db_name']}""
  print_line_to_inventory_file "db_user="${VARS['db_user']}""
  print_line_to_inventory_file "db_password="${VARS['db_password']}""
  print_line_to_inventory_file "admin_login="${VARS['admin_login']}""
  print_line_to_inventory_file "admin_password="${VARS['admin_password']}""
}


print_line_to_inventory_file(){
  local line="${1}"
  debug "  "$line"" 'light.blue'
  echo "$line" >> "$INVENTORY_FILE"
}



stage4(){
  debug "Starting stage 4: install ansible"
  install_ansible_if_not_installed
}



install_ansible_if_not_installed(){
  if ! is_installed ansible; then
    debug "Try to install ansible"
    install_package epel-release
    install_package ansible
  fi
}



stage5(){
  debug "Starting stage 5: run ansible playbook"
  download_provision
  run_ansible_playbook
}



download_provision(){
  release_url="https://github.com/keitarocorp/centos_provision/archive/master.tar.gz"
  run_command "curl -sSL "$release_url" | tar xz"
}



run_ansible_playbook(){
  run_command "ansible-playbook -vvv -i ${INVENTORY_FILE} ${PROVISION_DIRECTORY}/playbook.yml"
  clean_up
  show_successful_message
}



show_successful_message(){
  print_with_color "$(translate 'messages.successful')" 'green'
  if isset "${VARS['ssl_domains']}"; then
    protocol='https'
    domain=$(expr match "${VARS['ssl_domains']}" '\([^,]*\)')
  else
    protocol='http'
    domain="${VARS['license_ip']}"
  fi
  print_with_color "${protocol}://${domain}/admin" 'light.green'
  colored_login=$(print_with_color "${VARS['admin_login']}" 'light.green')
  colored_password=$(print_with_color "${VARS['admin_password']}" 'light.green')
  echo -e "login: ${colored_login}"
  echo -e "password: ${colored_password}"
}








install(){
  init "$@"
  stage1 "$@"
  stage2
  stage3
  stage4
  stage5
}


install "$@"

# wait for all async child processes (because "await ... then" is used in powscript)
[[ $ASYNC == 1 ]] && wait


exit 0

