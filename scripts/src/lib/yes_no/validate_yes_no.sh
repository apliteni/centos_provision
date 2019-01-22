#!/usr/bin/env bash
validate_yes_no(){
  local value="${1}"
  (is_yes "$value" || is_no "$value")
}
