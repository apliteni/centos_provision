#!/usr/bin/env bash

print_prompt_help(){
  local var_name="${1}"
  print_translated "prompts.$var_name.help"
}
