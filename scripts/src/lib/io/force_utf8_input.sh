#!/usr/bin/env bash

force_utf8_input(){
  LC_CTYPE=en_US.UTF-8
  if [ -f /proc/$$/fd/1 ]; then
    stty -F /proc/$$/fd/1 iutf8
  fi
}
