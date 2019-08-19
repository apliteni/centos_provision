#!/usr/bin/env bash

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  run_obsolete_tool_version_if_need
}
