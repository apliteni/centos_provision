#!/usr/bin/env bash

parse_options(){
  while getopts ":D:R:L:l:vhsp" option; do
    argument=$OPTARG
    case $option in
      D)
        VARS['site_domains']=$argument
        ensure_valid D site_domains validate_domains_list
        ;;
      R)
        VARS['site_root']=$argument
        ensure_valid R site_root validate_directory_existence
        ;;
      *)
        common_parse_options "$option" "$argument"
        ;;
    esac
  done
  ensure_options_correct
}


help_ru(){
  print_err "$SCRIPT_NAME позволяет запустить дополнительный сайт совместно с Keitaro"
  print_err "Пример: "$SCRIPT_NAME" -L ru -D domain1.tld,domain2.tld -R /var/www/domain1.tld"
  print_err
  print_err "Автоматизация:"
  print_err "  -D DOMAINS               задать список доменов, DOMAINS=domain1.tld[,domain2.tld...]"
  print_err
  print_err "  -R PATH                  задать существующий путь к корневой директории сайта"
  print_err
}


help_en(){
  print_err "$SCRIPT_NAME allows to run additional site together with Keitaro"
  print_err "Example: "$SCRIPT_NAME" -L en -D domain1.tld,domain2.tld -R /var/www/domain1.tld"
  print_err
  print_err "Script automation:"
  print_err "  -D DOMAINS               set list of domains, DOMAINS=domain1.tld[,domain2.tld...]"
  print_err
  print_err "  -R PATH                  set existent path to the site root"
  print_err
}
