#!/usr/bin/env bash
force_import=""

show_help() {
  echo ""
  echo "Usage: $0 -F DUMP_FILE [-d DATABASE_NAME] [-a ASYNC_TABLE_NAMES] [-r REPLACE_FROM] [-t REPLACE_TO] [-H host]"
  echo "Example: $0 -F backup.sql.gz -d booking -a \"table_name|table2_name\" -f incorrect -t correct -H localhost"
  exit 1
}

parse_options() {
  while getopts "F:d:a:r:t:v:H:hf" option; do
  argument=$OPTARG
  ARGS["${option}"]="${argument}"
    case $option in
        h)
            show_help
            exit 0
            ;;
        F)  dump_path=$argument
            ;;
        H) host=$argument
            ;;
        d)  db_name=$argument
            ;;
        a)  asynchronously_imported_tables_regex=$argument
            ;;
        r)  replace_table_prefix_from=$argument
            ;;
        t)  replace_table_prefix_to=$argument
            ;;
        v)  validated_tables=$argument
            ;;
        f) force_import="true"
            ;;
        \? ) echo "Invalid option: $argument" 1>&2
            show_help >&2
            ;;
    esac
  done
  if [[ -z "$host" ]]; then
    mysql_host="localhost"
  else
    mysql_host="$host"
  fi

  if [[ "${force_import}" == "" ]]; then
    exec 3<>/dev/tty
    read -u 3 -p "This script will destroy the data in the keitaro database, are you sure you want to continue (yes|no)" yn
    case $yn in
        [Yy]*) ;;
        [Nn]*) exit
               ;;
        * )    echo "Please answer yes or no."
               exit
               ;;
    esac
  fi
}

define_dump_path() {
  local dump_path=${1}
  if [[ $(dirname "${dump_path}") == '.' ]]; then
    echo $(pwd)/$(basename "${dump_path}")
  else
    echo "${dump_path}"
  fi
}

ensure_nobody_is_using_database() {
  local parallel_processes_list=$(mysql --host="$mysql_host" --execute='SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND = "Query" AND DB = "keitaro"';)
  if [[ $parallel_processes_list ]]; then
    echo "Database Keitaro used by another process"
    exit 1
  fi
}

ensure_options_are_valid() {
  if [[ -z "${dump_path}" ]]; then
    echo "-F parameter is required"
    show_help
  fi

  if [[ ! -f "$dump_path" ]]; then
      echo "keitaro dump does not exists"
      exit 1
  fi

  if [[ -z "${db_name}" ]]; then
      echo "database name does not set"
      exit 1
  fi

  if [[ -z "${asynchronously_imported_tables_regex}" ]]; then
      echo "tables name does not set"
      exit 1
  fi
}

ensure_dump_is_valid() {
  local tables_name="${validated_tables}"

  for table_name in $tables_name; do
    if [[ ! -f ${table_name}.sql ]]; then
      echo -e "\e[31mTable with prefix ${table_name}.sql does not exist\e[0m"
      exit 1
    fi
  done
}

make_dump_dir() {
  mktemp -d
}

define_handling_command() {
  if [[ ${1##*.} == "gz" ]]; then
    echo "zcat"
  else
    echo "cat"
  fi
}

make_micro_dumps() {
  generate_micro_dump_optimization_sql "${1}"
  unpack_db_dump_to_chunks
  adapt_chunks_to_micro_dumps
}

generate_micro_dump_optimization_sql () {
  local dump_dir="${1}"
  prepend="SET GLOBAL max_connections = 200;"
  prepend="$prepend SET UNIQUE_CHECKS = 0; "
  prepend="$prepend SET AUTOCOMMIT = 0; "
  echo "$prepend" > "$dump_dir/prepend.sql"

  append="SET UNIQUE_CHECKS = 1; "
  append="$append SET AUTOCOMMIT = 1; "
  append="$append COMMIT ; "
  echo "$append" > "$dump_dir/append.sql"
}

unpack_db_dump_to_chunks() {
  local
  if  $(define_handling_command "${dump_path}") "${dump_path}" | awk -v file_name=table0 '/^-- Table structure for table/{file_name="table"++i;}(file_name){print > file_name;}'; then
    echo 'Success split dump tables'
  else
    echo -e '\e[31mDump tables split failed\e[0m'
    exit 1
  fi
}

rename_table_prefix() {
  if [[ ! -z "${replace_table_prefix_from}" ]] && [[ $replace_table_prefix_from != $replace_table_prefix_to ]]; then
    sed "s/$replace_table_prefix_from/$replace_table_prefix_to/"
  else
    cat
  fi
}

adapt_chunks_to_micro_dumps() {
  mv table0 head
  for file in table*; do
    table_name=$(head -n1 "$file" | cut -d$'\x60' -f2)
    cat head prepend.sql "$file" append.sql | rename_table_prefix > "$table_name.sql"
  done
  ensure_dump_is_valid
  echo "Split to micro dumps successfully completed"
}

clean_up_db() {
  rm prepend.sql append.sql head table*
  mysql --host="$mysql_host" -e "DROP DATABASE $db_name; CREATE DATABASE $db_name"
}

mysql_import(){
  nohup mysql --host="$mysql_host" "$2" < "$1" > /dev/null 2>&1
}

async_restore_dump() {
  for file in *; do
    mysql_import "$file" "$db_name" &

    table_name=${file%".sql"}
    if [[ ! "$table_name" =~ $asynchronously_imported_tables_regex ]]; then
      pids+=($!)
    fi
  done

  wait "${pids[@]}"
  echo "Async dump restore successfully completed"
}

remove_dir() {
  local dump_dir="${1}"
  rm -rf "$dump_dir"
}

parse_options "$@"
dump_path=$(define_dump_path "${dump_path}")
ensure_options_are_valid
ensure_nobody_is_using_database
working_dir=$(make_dump_dir)
pushd "$working_dir" || { echo "Failure to change directory"; exit 1; }
make_micro_dumps "${working_dir}"
clean_up_db
async_restore_dump
popd || { echo "Failure to change working directory"; exit 1; }
remove_dir "$working_dir"

echo "Some parts of the dump will be imported in background. "
