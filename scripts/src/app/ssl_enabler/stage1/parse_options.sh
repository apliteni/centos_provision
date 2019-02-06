#!/usr/bin/env bash
#





parse_options(){
  while getopts ":hpsl:ae:wv" opt; do
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
            exit ${FAILURE_RESULT}
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
        exit ${FAILURE_RESULT}
        ;;
      h)
        usage
        exit ${SUCCESS_RESULT}
        ;;
      v)
        echo "${SCRIPT_NAME} v${RELEASE_VERSION}"
        exit ${SUCCESS_RESULT}
        ;;
      \?)
        usage
        exit ${FAILURE_RESULT}
        ;;
    esac
  done
  shift $((OPTIND-1))
  if [[ ${#} == 0 ]]; then
    usage
    exit ${FAILURE_RESULT}
  else
    while [[ ${#} -gt 0 ]]; do
      if [[ "$1" =~ (,) ]]; then
        usage
        exit ${FAILURE_RESULT}
      fi
      if [[ ! "${1}" =~ ^(-) ]]; then
        if validate_domain "${1}"; then
          DOMAINS+=("$(to_lower "${1}")")
        else
          set_ui_lang
          fail "$(translate 'errors.domain_invalid' "domain=${1}")"
        fi
      fi
      shift
    done
  fi
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
  print_err "$SCRIPT_NAME подключает SSL сертификат от Let's Encrypt для указанных доменов Keitaro"
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
  print_err "$SCRIPT_NAME generates Let's Encrypt SSL for the specified domains of Keitaro"
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
