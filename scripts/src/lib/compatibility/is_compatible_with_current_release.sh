#!/usr/bin/env bash


is_compatible_with_current_release(){
  local current_major_release=${RELEASE_VERSION/\.*/}
  local installed_major_release=${INSTALLED_VERSION/\.*/}
  [[ "${installed_major_release}" == "${current_major_release}" ]]
}
