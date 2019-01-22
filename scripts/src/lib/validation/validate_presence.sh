#!/usr/bin/env bash
#





validate_presence(){
  local value="${1}"
  isset "$value"
}
