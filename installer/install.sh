#!/usr/bin/env bash

usage() {
  progname=$(basename $0)
  cat <<USAGE
    ${progname} installs Keitarotds

    Usage: ${progname} [-p]

        -p      The -p (preserve installation) option causes ${progname} to preserve the invoking installation commands. Installation commands will be printed to stdout instead.

USAGE
}

while getopts ":pv" opt; do
  case $opt in
    p)
      echo "-p was triggered" >&2
      PRESERVE_MODE=true
      ;;
    v)
      echo "-v was triggered" >&2 
      VERBOSE_MODE=true
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

echo '123'

exit 0
