#!/usr/bin/env bash

# Based on https://stackoverflow.com/a/53400482/612799
#
# Use:
#   (( $(version_to_number 1.2.3.4) >= $(version_to_number 1.2.3.3) )) && echo "yes" || echo "no"
#
# Version number should not contain more than 4 parts (3 dots) and each part should not contain more than 3 digits
#
version_to_number() {
  local version="${1}"
  local dots="${version//[^.]}"
  if [[ ${#dots} > 3 ]]; then
    debug "Version number '${version}' has more than 3 dots"
    fail "Internal error - wrong version format"
  fi
  if [[ "${version}" =~ [[:digit:]]{4,} ]]; then
    debug "Version number '${version}' some part has more than 3 digits"
    fail "Internal error - wrong version format"
  fi
  printf "%03d%03d%03d%03d" ${version//./ }
}
