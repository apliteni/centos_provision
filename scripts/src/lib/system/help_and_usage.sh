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
          print_err "Specified language '$argument' is not supported"
          exit ${FAILURE_RESULT}
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
    *)
      wrong_options
      ;;
  esac
}


help(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    usage_ru_header
    help_ru
    help_ru_common
  else
    usage_en_header
    help_en
    help_en_common
  fi
  exit ${SUCCESS_RESULT}
}


usage(){
  if [[ $(get_ui_lang) == 'ru' ]]; then
    usage_ru
  else
    usage_en
  fi
  exit ${FAILURE_RESULT}
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


usage_ru(){
  usage_ru_header
  print_err "Попробуйте '${SCRIPT_NAME} -h' для большей информации."
  print_err
}


usage_en(){
  usage_en_header
  print_err "Try '${SCRIPT_NAME} -h' for more information."
  print_err
}


usage_ru_header(){
  print_err "Использование: "$SCRIPT_NAME" [OPTION]..."
}


usage_en_header(){
  print_err "Usage: "$SCRIPT_NAME" [OPTION]..."
}


help_ru_common(){
  print_err "Интернационализация:"
  print_err "  -L LANGUAGE              задать язык - en или ru соответсвенно для английского или русского языка"
  print_err
  print_err "Разное:"
  print_err "  -h                       показать эту справку выйти"
  print_err
  print_err "  -v                       показать версию и выйти"
  print_err
}


help_en_common(){
  print_err "Internationalization:"
  print_err "  -L LANGUAGE              set language - either en or ru for English and Russian appropriately"
  print_err
  print_err "Miscellaneous:"
  print_err "  -h                       display this help text and exit"
  print_err
  print_err "  -v                       display version information and exit"
  print_err
}
