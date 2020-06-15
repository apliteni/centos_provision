#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

_require 'lib/stdlib.sh'

_require 'shared/vars/test_run_command_program_name.sh'
_require 'shared/vars/common.sh'
_require 'shared/vars/dict.sh'

_require 'lib/i18n/set_ui_lang.sh'
_require 'lib/i18n/translate.sh'
_require 'lib/io/add_indentation.sh'
_require 'lib/io/force_utf8_input.sh'
_require 'lib/io/read_stdin.sh'
_require 'lib/system/clean_up.sh'
_require 'lib/system/debug.sh'
_require 'lib/system/fail.sh'
_require 'lib/system/init.sh'
_require 'lib/system/init_kctl.sh'
_require 'lib/system/log_and_print_err.sh'
_require 'lib/system/on_exit.sh'
_require 'lib/system/print_content_of.sh'
_require 'lib/system/print_err.sh'
_require 'lib/system/print_translated.sh'
_require 'lib/system/print_with_color.sh'
_require 'lib/system/run_command.sh'

_require 'app/installer/stage6/run_ansible_playbook.sh'
_require 'app/installer/stage6/json2dict.sh'


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html

test_run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local failed_logs_filter="${6}"
  UI_LANG=en
  init
  run_command "${command}" "${message}" "${hide_output}" "${allow_errors}" "${run_as}" "${failed_logs_filter}"
}


test_run_command "${1}" "${2}" "${3}" "${4}" "${5}" "${6}"
