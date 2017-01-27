#!/usr/bin/env bash

# Generated by POWSCRIPT (https://github.com/coderofsalvation/powscript)
#
# Unless you like pain: edit the .pow sourcefiles instead of this file

# powscript general settings
set -e                         # halt on error
set +m                         #
SHELL="$(echo $0)"             # shellname
SHELLNAME="$(basename $SHELL)" # shellname without path
shopt -s lastpipe              # flexible while loops (maintain scope)
shopt -s extglob               # regular expressions
path="$(pwd)"
selfpath="$( dirname "$(readlink -f "$0")" )"
tmpfile="/tmp/$(basename $0).tmp.$(whoami)"
echo 'compile error: couldn't find required file: ssl_enabler/vars/common.pow'; exit 1;

# wait for all async child processes (because "await ... then" is used in powscript)
[[ $ASYNC == 1 ]] && wait


exit 0

