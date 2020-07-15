#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

_require 'lib/stdlib.sh'
_require 'shared/vars/ssl_enabler_program_name.sh'
_require 'shared/vars/common.sh'
_require 'shared/vars/dict.sh'

_require 'app/ssl_enabler/vars/common.sh'
_require 'app/ssl_enabler/vars/dict.sh'

_require 'lib/asserts/assert_caller_root.sh'
_require 'lib/asserts/assert_installed.sh'
_require 'lib/asserts/is_file_exist.sh'
_require 'lib/asserts/is_file_matches.sh'
_require 'lib/asserts/is_directory_exist.sh'
_require 'lib/compatibility/as_version.sh'
_require 'lib/compatibility/detect_installed_version.sh'
_require 'lib/compatibility/run_obsolete_tool_version_if_need.sh'
_require 'lib/i18n/set_ui_lang.sh'
_require 'lib/i18n/translate.sh'
_require 'lib/install/is_installed.sh'
_require 'lib/inventory/detect_inventory_path.sh'
_require 'lib/io/add_indentation.sh'
_require 'lib/io/force_utf8_input.sh'
_require 'lib/io/get_user_var.sh'
_require 'lib/io/hack_stdin.sh'
_require 'lib/io/print_prompt.sh'
_require 'lib/io/print_prompt_error.sh'
_require 'lib/io/print_prompt_help.sh'
_require 'lib/io/read_stdin.sh'
_require 'lib/nginx/generate_vhost.sh'
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
_require 'lib/system/reload_nginx.sh'
_require 'lib/system/run_command.sh'
_require 'lib/system/help_and_usage.sh'
_require 'lib/util/join_by.sh'
_require 'lib/util/to_lower.sh'
_require 'lib/validation/ensure_valid.sh'
_require 'lib/validation/get_error.sh'
_require 'lib/validation/validate_domain.sh'
_require 'lib/validation/validate_domains_list.sh'
_require 'lib/validation/validate_presence.sh'
_require 'lib/yes_no/is_no.sh'
_require 'lib/yes_no/is_yes.sh'
_require 'lib/yes_no/transform_to_yes_no.sh'
_require 'lib/yes_no/validate_yes_no.sh'

_require 'app/ssl_enabler/stage1.sh'
_require 'app/ssl_enabler/stage1/parse_options.sh'
_require 'app/ssl_enabler/stage2.sh'
_require 'app/ssl_enabler/stage3.sh'
_require 'app/ssl_enabler/stage3/get_user_vars.sh'
_require 'app/ssl_enabler/stage4.sh'
_require 'app/ssl_enabler/stage4/add_renewal_job.sh'
_require 'app/ssl_enabler/stage4/generate_certificates.sh'
_require 'app/ssl_enabler/stage4/generate_vhost_ssl_enabler.sh'
_require 'app/ssl_enabler/stage4/show_finishing_message.sh'
_require 'app/ssl_enabler/stage4/recognize_error.sh'


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html
enable_ssl(){
  init "$@"
  stage1 "$@"
  stage2
  stage3
  stage4
}

enable_ssl "$@"

