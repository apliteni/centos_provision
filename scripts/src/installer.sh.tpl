#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

_require 'lib/stdlib.sh'

_require 'shared/vars/installer_program_name.sh'
_require 'shared/vars/common.sh'
_require 'shared/vars/dict.sh'

_require 'lib/asserts/assert_caller_root.sh'
_require 'lib/asserts/assert_installed.sh'
_require 'lib/asserts/assert_keitaro_not_installed.sh'
_require 'lib/asserts/is_file_exist.sh'
_require 'lib/compatibility/assert_config_relevant_or_upgrade_running.sh'
_require 'lib/compatibility/detect_installed_version.sh'
_require 'lib/i18n/set_ui_lang.sh'
_require 'lib/i18n/translate.sh'
_require 'lib/io/add_indentation.sh'
_require 'lib/io/detect_mime_type.sh'
_require 'lib/io/get_user_var.sh'
_require 'lib/io/force_utf8_input.sh'
_require 'lib/io/hack_stdin.sh'
_require 'lib/io/is_pipe_mode.sh'
_require 'lib/io/print_prompt.sh'
_require 'lib/io/print_prompt_error.sh'
_require 'lib/io/print_prompt_help.sh'
_require 'lib/io/read_stdin.sh'
_require 'lib/install/install_package.sh'
_require 'lib/install/is_installed.sh'
_require 'lib/inventory/detect_inventory_path.sh'
_require 'lib/system/debug.sh'
_require 'lib/system/fail.sh'
_require 'lib/system/help_and_usage.sh'
_require 'lib/system/init.sh'
_require 'lib/system/init_log.sh'
_require 'lib/system/log_and_print_err.sh'
_require 'lib/system/on_exit.sh'
_require 'lib/system/print_content_of.sh'
_require 'lib/system/print_err.sh'
_require 'lib/system/print_translated.sh'
_require 'lib/system/print_with_color.sh'
_require 'lib/system/run_command.sh'
_require 'lib/util/detect_license_ip.sh'
_require 'lib/util/get_host_ips.sh'
_require 'lib/util/join_by.sh'
_require 'lib/validation/get_error.sh'
_require 'lib/validation/ensure_valid.sh'
_require 'lib/validation/validate_domain.sh'
_require 'lib/validation/validate_domains_list.sh'
_require 'lib/validation/validate_alnumdashdot.sh'
_require 'lib/validation/validate_ip.sh'
_require 'lib/validation/validate_keitaro_dump.sh'
_require 'lib/validation/validate_license_key.sh'
_require 'lib/validation/validate_not_root.sh'
_require 'lib/validation/validate_not_reserved_word.sh'
_require 'lib/validation/validate_presence.sh'
_require 'lib/validation/validate_file_existence.sh'
_require 'lib/validation/validate_starts_with_latin_letter.sh'
_require 'lib/yes_no/is_no.sh'
_require 'lib/yes_no/is_yes.sh'
_require 'lib/yes_no/transform_to_yes_no.sh'
_require 'lib/yes_no/validate_yes_no.sh'

_require 'app/installer/vars/common.sh'
_require 'app/installer/vars/dict.sh'

_require 'app/installer/lib/system/clean_up.sh'
_require 'app/installer/lib/system/get_var_from_config.sh'
_require 'app/installer/lib/system/write_inventory_on_reconfiguration.sh'

_require 'app/installer/stage1.sh'
_require 'app/installer/stage1/check_thp_disable_possibility.sh'
_require 'app/installer/stage1/parse_options.sh'
_require 'app/installer/stage1/setup_vars.sh'
_require 'app/installer/stage2.sh'
_require 'app/installer/stage2/assert_apache_not_installed.sh'
_require 'app/installer/stage2/assert_centos_distro.sh'
_require 'app/installer/stage2/assert_pannels_not_installed.sh'
_require 'app/installer/stage2/assert_has_enough_ram.sh'
_require 'app/installer/stage3.sh'
_require 'app/installer/stage3/read_inventory.sh'
_require 'app/installer/stage4.sh'
_require 'app/installer/stage4/get_user_vars.sh'
_require 'app/installer/stage4/write_inventory_file.sh'
_require 'app/installer/stage5.sh'
_require 'app/installer/stage6.sh'
_require 'app/installer/stage6/download_provision.sh'
_require 'app/installer/stage6/run_ansible_playbook.sh'
_require 'app/installer/stage6/show_credentials.sh'
_require 'app/installer/stage6/show_successful_message.sh'
_require 'app/installer/stage6/json2dict.sh'

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html

install(){
  init "$@"
  stage1 "$@"                 # initial script setup
  stage2                    # make some asserts
  stage3                    # read vars from the inventory file
  if isset "$RECONFIGURE"; then
    assert_config_relevant_or_upgrade_running
    write_inventory_on_reconfiguration
  else
    assert_keitaro_not_installed
    stage4                  # get and save vars to the inventory file
    stage5                  # upgrade packages and install ansible
  fi
  stage6                    # run ansible playbook
}

install "$@"
