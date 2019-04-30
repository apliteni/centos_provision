#!/usr/bin/env bash
#





parse_options(){
  while getopts ":D:L:l:hvps" option; do
    argument=$OPTARG
    case $option in
      D)
        VARS['ssl_domains']=$argument
        ensure_valid D ssl_domains validate_domains_list
        ;;
      *)
        common_parse_options "$option" "$argument"
        ;;
    esac
  done
  ensure_options_correct
  get_domains_from_arguments ${@}
}


get_domains_from_arguments(){
  shift $((OPTIND-1))
  if [[ ${#} == 0 ]]; then
    return
  fi
  if isset "${VARS['ssl_domains']}"; then
    fail "You should set domains with -d option only"
  fi
  print_err "DEPRECATION WARNING: Please set domains with -D option" "yellow"
  while [[ ${#} -gt 0 ]]; do
    if validate_domain "$1"; then
      DOMAINS+=("$(to_lower "${1}")")
    else
      fail "$1 - invalid domain"
    fi
    shift
  done
  VARS['ssl_domains']="$(join_by "," "${DOMAINS[@]}")"
}



help_ru(){
  print_err "$SCRIPT_NAME подключает SSL сертификат от Let's Encrypt и генерирует кофигурацию nginx"
  print_err "Использование этой программы подразумевает принятие условий соглашения подписки Let's Encrypt."
  print_err "Пример: "$SCRIPT_NAME" -L ru -D domain1.tld,domain2.tld"
  print_err
  print_err "Автоматизация:"
  print_err "  -D DOMAINS               выписать сертификаты для списка доменов, DOMAINS=domain1.tld[,domain2.tld...]."
  print_err
}


help_en(){
  print_err "$SCRIPT_NAME issues Let's Encrypt SSL certificate and generates nginx configuration"
  print_err "The use of this program implies acceptance of the terms of the Let's Encrypt Subscriber Agreement."
  print_err "Example: "$SCRIPT_NAME" -L en -D domain1.tld,domain2.tld"
  print_err
  print_err "Script automation:"
  print_err "  -D DOMAINS               issue certs for domains, DOMAINS=domain1.tld[,domain2.tld...]."
  print_err
}
