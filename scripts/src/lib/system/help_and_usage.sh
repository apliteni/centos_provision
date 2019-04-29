#!/usr/bin/env bash
#




common_parse_options(){
  local option="${1}"
  local argument="${2}"
  case $option in
    l|L)
      case $argument in
        en)
          UI_LANG=en
          ;;
        ru)
          UI_LANG=ru
          ;;
        *)
          wrong_options
          ;;
      esac
      ;;
    v)
      version
      ;;
    h)
      help
      ;;
    s)
      SKIP_CHECKS=true
      ;;
    p)
      PRESERVE_RUNNING=true
      ;;
    :)
      wrong_options
      ;;
    \?)
      wrong_options
      ;;
  esac
}


help(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    ru_help
  else
    en_help
  fi
  exit ${SUCCESS_RESULT}
}


usage(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    usage_ru
    usage_ru_common
  else
    usage_en
    usage_en_common
  fi
  exit ${FAILURE_RESULT}
}


usage_ru_common(){
  print_err "Интернационализация:"
  print_err "  -L LANGUAGE              задать язык - en или ru соответсвенно для английского или русского языка"
  print_err
  print_err "Разное:"
  print_err "  -v                       показать версию и выйти"
  print_err
  print_err "  -h                       показать эту справку выйти"
  print_err
}


usage_en_common(){
  print_err "Internationalization:"
  print_err "  -L LANGUAGE              set language - either en or ru for English and Russian appropriately"
  print_err
  print_err "Miscellaneous:"
  print_err "  -v                       display version information and exit"
  print_err
  print_err "  -h                       display this help text and exit"
  print_err
}


version(){
  echo "${SCRIPT_NAME} v${RELEASE_VERSION}"
  exit ${SUCCESS_RESULT}
}


wrong_options(){
  WRONG_OPTIONS="wrong_options"
}


ensure_options_correct(){
  if isset "${WRONG_OPTIONS}"; then
    usage
  fi
}
