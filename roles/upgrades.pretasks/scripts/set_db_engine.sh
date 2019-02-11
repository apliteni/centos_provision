#!/usr/bin/env bash

set -e                                # halt on error
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

KEITARO_CONFIG="/var/www/keitaro/application/config/config.ini.php"
ENGINE_TOKUDB=tokudb
ENGINE_INNODB=innodb
OLD_INVENTORY="${HOME}/hosts.txt"
NEW_INVENTORY="${HOME}/.keitaro/installer_config"

get_var_from_config(){
  local var="${1}"
  local file="${2}"
  local separator="${3}"
  cat "$file" | \
    grep "^${var}\\b" | \
    grep "${separator}" | \
    head -n1 | \
    awk -F"${separator}" '{print $2}' | \
    awk '{$1=$1; print}' | \
    sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
}

ensure_file_exists() {
  local file="${1}"

  if [ ! -f "${file}" ]; then
    echo "${db_name}"
    echo "Can't find file ${file}"
    exit 1
  fi
}

read_db_name_from() {
  local file="${1}"

  ensure_file_exists "${1}"

  db_name="$(get_var_from_config "name" "${file}" "=")"

  if [[ "${db_name}" == "" ]]; then
    echo "Can't read database name from ${file}"
    exit 1
  fi

  echo "${db_name}"
}

detect_engine() {
  local db_name="${1}"

  if mysqldump -d "${db_name}" | grep -ioP 'engine=\w+' | grep -iq tokudb; then
    echo "${ENGINE_TOKUDB}"
  else
    echo "${ENGINE_INNODB}"
  fi
}

set_db_engine() {
  local db_engine="${1}"
  local hosts_file="${2}"

  echo "db_engine=${db_engine}" >> ${hosts_file}
}

db_name="$(read_db_name_from "${KEITARO_CONFIG}")"

db_engine="$(detect_engine "${db_name}")"

if [ -f "${NEW_INVENTORY}" ]; then
  set_db_engine "${db_engine}" "${NEW_INVENTORY}"
else
  set_db_engine "${db_engine}" "${OLD_INVENTORY}"
fi
