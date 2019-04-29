#!/usr/bin/env bash
#






parse_options(){
  while getopts ":A:K:ra:t:i:k:L:l:hvps" option; do
    argument=$OPTARG
    case $option in
      A)
        VARS['license_ip']=$argument
        ;;
      K)
        VARS['license_key']=$argument
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
  if isset "${VARS['license_ip']}" && isset "${VARS['license_key']}"; then
    RECONFIGURE="true"
  fi
  ensure_options_correct
}


help_ru(){
  print_err "$SCRIPT_NAME уставливает и настраивает Keitaro"
  print_err "Пример: "$SCRIPT_NAME" -L ru -A a.b.c.d -K AAAA-BBBB-CCCC-DDDD"
  print_err
  print_err "Автоматизация:"
  print_err "  -A IP_ADDRESS            задать IP адрес лицензии Keitaro"
  print_err
  print_err "  -K LICENSE_KEY           задать ключ лицензии Keitaro"
  print_err
  print_err "  -r                       отключить интерактивный режим (-A совместно с -K подразумевает -r)"
  print_err
  print_err "Настройка:"
  print_err "  -a PATH_TO_PACKAGE       устанавить Keitaro из пакета"
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
  print_err "Example: "$SCRIPT_NAME" -L en -A a.b.c.d -K AAAA-BBBB-CCCC-DDDD"
  print_err
  print_err "Script automation:"
  print_err "  -A                       set Keitaro license IP"
  print_err
  print_err "  -K                       set Keitaro license key"
  print_err
  print_err "  -r                       disable interactive mode (setting -A among with -K implies -r)"
  print_err
  print_err "Customization:"
  print_err "  -a PATH_TO_PACKAGE       use Keitaro package for installation"
  print_err
  print_err "  -t TAGS                  set ansible-playbook tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -i TAGS                  set ansible-playbook ignore tags, TAGS=tag1[,tag2...]"
  print_err
  print_err "  -k RELEASE               set Keitaro release, 8 and 9 are only valid values"
  print_err
}
