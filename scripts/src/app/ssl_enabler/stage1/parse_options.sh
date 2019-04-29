#!/usr/bin/env bash

parse_options(){
  while getopts "ae:wL:l:vhsp" option; do
    argument=$OPTARG
    case $option in
      a)
        SKIP_SSL_AGREE_TOS=true
        ;;
      e)
        SKIP_SSL_EMAIL=""
        EMAIL="${OPTARG}"
        ;;
      w)
        SKIP_SSL_EMAIL=skip_ssl_email
        EMAIL=""
        ;;
      *)
        common_parse_options "$option" "$argument"
        ;;
    esac
  done
  shift $((OPTIND-1))
  if [[ ${#} == 0 ]]; then
    wrong_options
  else
    while [[ ${#} -gt 0 ]]; do
      if validate_domain "$1"; then
        DOMAINS+=("$(to_lower "${1}")")
      else
        wrong_options
        break
      fi
      shift
    done
  fi
  ensure_options_correct
}


usage_ru(){
  print_err "Использование: "$SCRIPT_NAME" [OPTION]... domain1.tld ..."
  print_err "Попробуйте '${SCRIPT_NAME} -h' для большей информации."
  print_err
}


help_ru(){
  print_err "Использование: "$SCRIPT_NAME" [OPTION]... domain1.tld ..."
  print_err "$SCRIPT_NAME подключает SSL сертификат от Let's Encrypt и генерирует кофигурацию nginx"
  print_err "Пример: "$SCRIPT_NAME" -l ru -a -w domain1.tld domain2.tld"
  print_err
  print_err "Автоматизация:"
  print_err "  -a                       подразумевает принятие пользовательского соглашения Let's Encrypt"
  print_err
  print_err "  -e EMAIL                 email адрес для получения уведомлений от Let's Encrypt (отключает -w)"
  print_err
  print_err "  -w                       не получать уведомления от Let's Encrypt (отключает -e)"
  print_err
}


usage_en(){
  print_err "Usage: "$SCRIPT_NAME" [OPTION]... domain1.tld ..."
  print_err "Try '${SCRIPT_NAME} -h' for more information."
  print_err
}


help_en(){
  print_err "Usage: "$SCRIPT_NAME" [OPTION]... domain1.tld ..."
  print_err "$SCRIPT_NAME issues Let's Encrypt SSL certificate and generates nginx configuration"
  print_err "Example: "$SCRIPT_NAME" -l en -a -w domain1.tld domain2.tld"
  print_err
  print_err "Script automation:"
  print_err "  -a                       implies accepting terms of Let's Encrypt license agreement"
  print_err
  print_err "  -e EMAIL                 email for notifications from Let's Encrypt (disables -w)"
  print_err
  print_err "  -w                       do not receive notifications from Let's Encrypt (disables -e)"
  print_err
}
