#!/usr/bin/env bash
#





get_user_vars(){
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  get_user_le_sa_agreement
  if is_yes ${VARS['ssl_agree_tos']}; then
    get_user_email
  else
    fail "$(translate 'prompts.ssl_agree_tos.help')"
  fi
}


get_user_le_sa_agreement(){
  VARS['ssl_agree_tos']='yes'
  if isset "$SKIP_SSL_AGREE_TOS"; then
    debug "Do not request SSL user agreement because appropriate option specified"
  else
    get_user_var 'ssl_agree_tos' 'validate_yes_no'
  fi
}


get_user_email(){
  if isset "$SKIP_SSL_EMAIL"; then
    debug "Do not request SSL email because appropriate option specified"
  else
    if isset "$EMAIL"; then
      debug "Do not request SSL email because email specified by option"
      VARS['ssl_email']="${EMAIL}"
    else
      get_user_var 'ssl_email'
    fi
  fi
}
