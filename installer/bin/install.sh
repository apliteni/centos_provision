#!/usr/bin/env bash

usage() {
  progname=$(basename $0)
  cat <<USAGE
  ${progname} installs Keitarotds

  Usage: ${progname} [-pv]

    -p      The -p (preserve installation) option causes ${progname} to preserve the invoking installation commands. Installation commands will be printed to stdout instead.
    -v      The -v (verbose mode) option causes ${progname} to display more verbose information of installation process.

USAGE
}

print_on_verbose() {
  if [ "${VERBOSE}" == "true" ]; then
    echo "${1}"
  fi
}

while getopts ":pv" opt; do
  case $opt in
    p)
      PRESERVE=true
      ;;
    v)
      VERBOSE=true
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

print_on_verbose "Verbose mode: on"

exit 0
