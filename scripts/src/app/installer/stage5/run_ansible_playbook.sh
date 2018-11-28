#!/usr/bin/env bash
#







ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^fatal: "
ANSIBLE_FAILURE_JSON_FILEPATH="${CONFIG_DIR}/ansible_failure.json"
ANSIBLE_LAST_TASK_LOG="${CONFIG_DIR}/ansible_last_task.log"


run_ansible_playbook(){
  local command="ANSIBLE_FORCE_COLOR=true ANSIBLE_CONFIG=${PROVISION_DIRECTORY}/ansible.cfg ansible-playbook -vvv -i ${INVENTORY_FILE} ${PROVISION_DIRECTORY}/playbook.yml"
  if isset "$ANSIBLE_TAGS"; then
    command="${command} --tags ${ANSIBLE_TAGS}"
  fi
  if isset "$ANSIBLE_IGNORE_TAGS"; then
    command="${command} --skip-tags ${ANSIBLE_IGNORE_TAGS}"
  fi
  run_command "${command}" '' '' '' '' 'print_ansible_fail_message'
}


print_ansible_fail_message(){
  local current_command_script="${1}"
  if ansible_task_found; then
    debug "Found last ansible task"
    print_tail_content_of "$CURRENT_COMMAND_ERROR_LOG"
    cat "$CURRENT_COMMAND_OUTPUT_LOG" | remove_text_before_last_pattern_occurence "$ANSIBLE_TASK_HEADER" > "$ANSIBLE_LAST_TASK_LOG"
    print_ansible_last_task_info
    print_ansible_last_task_external_info
    rm "$ANSIBLE_LAST_TASK_LOG"
  else
    print_common_fail_message "$current_command_script"
  fi
}


ansible_task_found(){
  grep -qE "$ANSIBLE_TASK_HEADER" "$CURRENT_COMMAND_OUTPUT_LOG"
}


print_ansible_last_task_info(){
  echo "Task info:"
  head -n2 "$ANSIBLE_LAST_TASK_LOG" | sed -r 's/\*+$//g' | add_indentation
}


print_ansible_last_task_external_info(){
  if ansible_task_failure_found; then
    debug "Found last ansible failure"
    cat "$ANSIBLE_LAST_TASK_LOG" \
      | keep_json_only \
      > "$ANSIBLE_FAILURE_JSON_FILEPATH"
    fi
    print_ansible_task_module_info
    rm "$ANSIBLE_FAILURE_JSON_FILEPATH"
  }


ansible_task_failure_found(){
  grep -q "$ANSIBLE_TASK_FAILURE_HEADER" "$ANSIBLE_LAST_TASK_LOG"
}


keep_json_only(){
  # The json with error is inbuilt into text. The structure of text is about:
  #
  # TASK [$ROLE_NAME : "$TASK_NAME"] *******
  # task path: /path/to/task/file.yml:$LINE
  # .....
  # fatal: [localhost]: FAILED! => {
  #     .....
  #     failure JSON
  #     .....
  # }
  # .....
  #
  # So, firstly remove all before "fatal: [localhost]: FAILED! => {" line
  # then replace first line to just '{'
  # then remove all after '}'
  sed -n -r "/${ANSIBLE_TASK_FAILURE_HEADER}/,\$p" \
    | sed '1c{' \
    | sed -e '/^}$/q'
  }


remove_text_before_last_pattern_occurence(){
  local pattern="${1}"
  sed -n -r "H;/${pattern}/h;\${g;p;}"
}


print_ansible_task_module_info(){
  declare -A   json
  eval "json=$(cat "$ANSIBLE_FAILURE_JSON_FILEPATH" | json2dict)" 2>/dev/null
  ansible_module="${json['invocation.module_name']}"
  echo "Ansible module: ${json['invocation.module_name']}"
  if isset "${json['msg']}"; then
    print_field_content "Field 'msg'" "${json['msg']}"
  fi
  if need_print_stdout_stderr "$ansible_module" "${json['stdout']}" "${json['stderr']}"; then
    print_field_content "Field 'stdout'" "${json['stdout']}"
    print_field_content "Field 'stderr'" "${json['stderr']}"
  fi
  if need_print_full_json "$ansible_module" "${json['stdout']}" "${json['stderr']}" "${json['msg']}"; then
    print_content_of "$ANSIBLE_FAILURE_JSON_FILEPATH"
  fi
}


print_field_content(){
  local field_caption="${1}"
  local field_content="${2}"
  if empty "${field_content}"; then
    echo "${field_caption} is empty"
  else
    echo "${field_caption}:"
    echo -e "${field_content}" | fold -s -w $((${COLUMNS:-80} - ${INDENTATION_LENGTH})) | add_indentation
  fi
}


need_print_stdout_stderr(){
  local ansible_module="${1}"
  local stdout="${2}"
  local stderr="${3}"
  isset "${stdout}"
  local is_stdout_set=$?
  isset "${stderr}"
  local is_stderr_set=$?
  [[ "$ansible_module" == 'cmd' || ${is_stdout_set} == ${SUCCESS_RESULT} || ${is_stderr_set} == ${SUCCESS_RESULT} ]]
}


need_print_full_json(){
  local ansible_module="${1}"
  local stdout="${2}"
  local stderr="${3}"
  local msg="${4}"
  need_print_stdout_stderr "$ansible_module" "$stdout" "$stderr"
  local need_print_output_fields=$?
  isset "$msg"
  is_msg_set=$?
  [[ ${need_print_output_fields} != ${SUCCESS_RESULT} && ${is_msg_set} != ${SUCCESS_RESULT}  ]]
}


get_printable_fields(){
  local ansible_module="${1}"
  local fields="${2}"
  echo "$fields"
}
