#!/usr/bin/env bash

usage() {
  progname=$(basename $0)
  cat >&2 <<USAGE
  ${progname} installs Keitarotds

  Usage: ${progname} [-pv] [-l en|ru]

    -p
        The -p (preserve installation) option causes ${progname} to preserve the invoking installation commands. Installation commands will be printed to stdout instead.

    -v
        The -v (verbose mode) option causes ${progname} to display more verbose information of installation process.

    -l <lang>
        By default ${progname} try to detect language from LANG environment variable, but you can explicitly set language with -l option.
        Only en and ru (for English and Russian) values supported now.

USAGE
}

print_on_verbose() {
  if [ "${VERBOSE}" == "true" ]; then
    echo "${1}"
  fi
}

echo ${LANG}
if [[ "${LANG}" =~ ^ru_[[:alpha:]]+\.UTF-8$ ]]; then
  LANGUAGE=ru
else
  LANGUAGE=en
fi
echo ${LANGUAGE}

while getopts ":pvl:" opt; do
  case $opt in
    p)
      PRESERVE=true
      ;;
    v)
      VERBOSE=true
      ;;
    l)
      case ${OPTARG} in
        en)
            LANGUAGE=en
            ;;
        ru)
            LANGUAGE=ru
            ;;
        *)
            echo "Specified language \"${OPTARG}\" is not supported" >&2
            exit 1
            ;;
      esac
      ;;
    :)
      echo "Option -${OPTARG} requires an argument." >&2
      exit 1
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

print_on_verbose "Verbose mode: on"
print_on_verbose "Language: ${LANGUAGE}"

cat > .keitarotds-hosts <<EOF
[server]
keitarotds

[server:vars]
db_name = ${HOSTS_DB_NAME}
db_user = ${HOSTS_DB_USER}
db_password = ${HOSTS_DB_PASSWORD}
license_ip = ${HOSTS_LICENSE_IP}
license_key = ${HOSTS_LICENSE_KEY}
admin_login = ${HOSTS_ADMIN_LOGIN}
admin_password = ${HOSTS_ADMIN_PASSWORD}
connection = local
EOF

exit 0
