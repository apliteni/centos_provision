#!/usr/bin/env bash

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_server_configuration_relevant
}
