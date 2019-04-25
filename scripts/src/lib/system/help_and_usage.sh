#!/usr/bin/env bash
#




common_parse_options(){
  local option="${1}"
  local argument="${2}"
  case $option in
    l)
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
    ru_usage
  else
    en_usage
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
