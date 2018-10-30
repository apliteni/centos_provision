#!/usr/bin/env bash
#





parse_options(){
  while getopts ":hpsrvl:t:k:i:a:" opt; do
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
      t)
        ANSIBLE_TAGS=$OPTARG
        ;;
      i)
        ANSIBLE_IGNORE_TAGS=$OPTARG
        ;;
      k)
        if [[ "$OPTARG" -ne 6 && "$OPTARG" -ne 7 && "$OPTARG" -ne 8 && "$OPTARG" -ne 9 ]]; then
          print_err "Specified Keitaro Release \"$OPTARG\" is not supported"
          exit ${FAILURE_RESULT}
        fi
        KEITARO_RELEASE=$OPTARG
        ;;
      a)
        CUSTOM_PACKAGE=$OPTARG
        ;;
      r)
        RECONFIGURE=true
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
  print_err "$SCRIPT_NAME устанавливает Keitaro"
  print_err
  print_err "Использование: "$SCRIPT_NAME" [-prs] [-l en|ru] [-t TAG1[,TAG2...]]"
  print_err
  print_err "  -p"
  print_err "    С опцией -p (preserve installation) "$SCRIPT_NAME" не запускает установочные команды. Вместо этого текс команд будет показан на экране."
  print_err
  print_err "  -r"
  print_err "    Используется только для переконфигурирования сервисов. ${INVENTORY_FILE} создаваться не будет."
  print_err
  print_err "  -s"
  print_err "    С опцией -s (skip checks) "$SCRIPT_NAME" не будет проверять присутствие yum/ansible в системе, не будет проверять факт запуска из под root."
  print_err
  print_err "  -l <language>"
  print_err "    "$SCRIPT_NAME" определяет язык через установленные переменные окружения LANG/LC_MESSAGES/LC_ALL, однако вы можете явно задать язык при помощи этого параметра."
  print_err "    На данный момент поддерживаются значения en и ru (для английского и русского языков)."
  print_err
  print_err "  -t <tag1[,tag2...]>"
  print_err "    Запуск ansible-playbook с указанными тэгами."
  print_err
  print_err "  -i <tag1[,tag2...]>"
  print_err "    Запуск ansible-playbook без выполнения указанных тэгов."
  print_err
  print_err "  -k <keitaro_release>"
  print_err "    "$SCRIPT_NAME" по умолчанию устанавливает текущую стабильную версию Keitaro. Вы можете явно задать устанавливаемую версию через этот параметр."
  print_err "    На данный момент поддерживаются значения 6, 7 и 8."
  print_err
}


en_usage(){
  print_err "$SCRIPT_NAME installs Keitaro"
  print_err
  print_err "Usage: "$SCRIPT_NAME" [-prs] [-l en|ru]"
  print_err
  print_err "  -p"
  print_err "    The -p (preserve installation) option causes "$SCRIPT_NAME" to preserve the invoking of installation commands. Installation commands will be printed to stdout instead."
  print_err
  print_err "  -r"
  print_err "    Use only for reconfiguration of services. In this mode installer does not create ${INVENTORY_FILE}."
  print_err
  print_err "  -s"
  print_err "    The -s (skip checks) option causes "$SCRIPT_NAME" to skip checks of yum/ansible presence, skip check root running"
  print_err
  print_err "  -l <language>"
  print_err "    By default "$SCRIPT_NAME" tries to detect language from LANG/LC_MESSAGES/LC_ALL environment variables, but you can explicitly set language with this option."
  print_err "    Only en and ru (for English and Russian) values are supported now."
  print_err
  print_err "  -t <tag1[,tag2...]>"
  print_err "    Runs ansible-playbook with specified tags."
  print_err
  print_err "  -i <tag1[,tag2...]>"
  print_err "    Runs ansible-playbook with skipping specified tags."
  print_err
  print_err "  -k <keitaro_release>"
  print_err "    By default "$SCRIPT_NAME" installs current stable Keitaro. You can specify Keitaro release with this option."
  print_err "    Only 6, 7 and 8 values are supported now."
  print_err
}
