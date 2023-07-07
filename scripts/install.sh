#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

umask 22


SUCCESS_RESULT=0
TRUE=0
FAILURE_RESULT=1
INTERRUPTED_BY_USER_RESULT=200
INTERRUPTED_ON_PARALLEL_RUN=201
FALSE=1
ROOT_UID=0


empty() {
  [[ "${#1}" == 0 ]] && return ${SUCCESS_RESULT} || return ${FAILURE_RESULT}
}

isset() {
  [[ ! "${#1}" == 0 ]] && return ${SUCCESS_RESULT} || return ${FAILURE_RESULT}
}

on() {
  func="$1";
  shift;
  for sig in "$@";
  do
      trap '"$func" "$sig"' "$sig";
  done
}

values() {
  echo "$2"
}

is_pipe_mode(){
  [ "${SELF_NAME}" == 'bash' ]
}


TOOL_NAME='install'

SELF_NAME=${0}

is_ci_mode() {
  [[ "$EUID" != "$ROOT_UID" || "${CI}" != "" ]]
}

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

CACHING_PERIOD_IN_DAYS="2"
CACHING_PERIOD_IN_MINUTES="$((CACHING_PERIOD_IN_DAYS * 24 * 60))"

RELEASE_VERSION='2.43.6'
VERY_FIRST_VERSION='0.9'

KCTL_IN_KCTL="${KCTL_IN_KCTL:-}"

KEITARO_URL='https://keitaro.io'
FILES_KEITARO_ROOT_URL="https://files.keitaro.io"
RELEASE_API_BASE_URL="https://release-api.keitaro.io"

KEITARO_SUPPORT_USER='keitaro-support'
KEITARO_SUPPORT_HOME_DIR="/home/${KEITARO_SUPPORT_USER}"

UPDATE_CHANNEL_ALPHA="alpha"
UPDATE_CHANNEL_BETA="beta"
UPDATE_CHANNEL_RC="rc"
UPDATE_CHANNEL_STABLE="stable"
DEFAULT_UPDATE_CHANNEL="${UPDATE_CHANNEL_STABLE}"

declare -a UPDATE_CHANNELS=( \
  "${UPDATE_CHANNEL_ALPHA}" \
  "${UPDATE_CHANNEL_BETA}" \
  "${UPDATE_CHANNEL_RC}" \
  "${UPDATE_CHANNEL_STABLE}" \
)


PATH_TO_ENV_DIR="${ROOT_PREFIX}/etc/keitaro/env"
PATH_TO_COMPONENTS_ENV="${PATH_TO_ENV_DIR}/components.env"
PATH_TO_SYSTEM_ENV="${PATH_TO_ENV_DIR}/system.env"
PATH_TO_APPLIED_COMPONENTS_ENV="${PATH_TO_ENV_DIR}/components-applied.env"

declare -A VARS
declare -A ARGS
declare -A DETECTED_VARS

TRACKER_ROOT="${ROOT_PREFIX}/var/www/keitaro"

KCTL_ROOT="${ROOT_PREFIX}/opt/keitaro"
KCTL_BIN_DIR="${KCTL_ROOT}/bin"
KCTL_LOG_DIR="${KCTL_ROOT}/log"
KCTL_ETC_DIR="${KCTL_ROOT}/etc"
KCTL_WORKING_DIR="${KCTL_ROOT}/tmp"

ETC_DIR="${ROOT_PREFIX}/etc/keitaro"

WORKING_DIR="${ROOT_PREFIX}/var/tmp/keitaro"

LOG_DIR="${ROOT_PREFIX}/var/log/keitaro"
SSL_LOG_DIR="${LOG_DIR}/ssl"

LOG_FILENAME="${TOOL_NAME}.log"
DEFAULT_LOG_PATH="${LOG_DIR}/${LOG_FILENAME}"
if [[ "${KCTLD_MODE}" == "" ]]; then
  LOG_PATH="${LOG_PATH:-${DEFAULT_LOG_PATH}}"
else
  LOG_PATH=/dev/stderr
fi

INVENTORY_DIR="${ETC_DIR}/config"
INVENTORY_PATH="${INVENTORY_DIR}/inventory"
PATH_TO_TRACKER_ENV="${INVENTORY_DIR}/tracker.env"
PATH_TO_KCTLD_ENV="${INVENTORY_DIR}/kctld.env"
DETECTED_INVENTORY_PATH=""

NGINX_CONFIG_ROOT="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_CONFIG_ROOT}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/keitaro.conf"

LETSENCRYPT_DIR="/etc/letsencrypt"

SCRIPT_NAME="kctl-${TOOL_NAME}"

CURRENT_COMMAND_OUTPUT_LOG="${WORKING_DIR}/current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="${WORKING_DIR}/current_command.error.log"
CURRENT_COMMAND_SCRIPT_NAME="current_command.sh"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

TOOL_ARGS="${*}"

DB_ENGINE_INNODB="innodb"
DB_ENGINE_TOKUDB="tokudb"
DB_ENGINE_DEFAULT="${DB_ENGINE_INNODB}"

OLAP_DB_MARIADB="mariadb"
OLAP_DB_CLICKHOUSE="clickhouse"
OLAP_DB_DEFAULT="${OLAP_DB_MARIADB}"

TRACKER_STABILITY_STABLE="stable"
TRACKER_STABILITY_UNSTABLE="unstable"
TRACKER_STABILITY_DEFAULT="${TRACKER_STABILITY_STABLE}"

KEITARO_USER='keitaro'
KEITARO_GROUP='keitaro'

TRACKER_CONFIG_FILE="${TRACKER_ROOT}/application/config/config.ini.php"
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='Please run this program as root.'
DICT['en.errors.upgrade_server']='You should upgrade the server configuration. Please contact Keitaro support team.'
DICT['en.errors.run_command.fail']='There was an error evaluating current command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.errors.unexpected']='Unexpected error'
DICT['en.errors.cant_upgrade']='Cannot upgrade because installation process is not finished yet'
DICT['en.errors.wrong_architecture']='Sorry, this script supports only x64 architecture.'
DICT['en.certbot_errors.another_proccess']="Another certbot process is already running"
DICT['en.messages.generating_nginx_vhost']="Generating nginx config for domain :domain:"
DICT['en.messages.reloading_nginx']="Reloading nginx"
DICT['en.messages.nginx_is_not_running']="Nginx is not running"
DICT['en.messages.starting_nginx']="Starting nginx"
DICT['en.messages.skip_nginx_conf_generation']="Skip nginx config generation"
DICT['en.messages.run_command']='Evaluating command'
DICT['en.messages.successful']='Everything is done!'
DICT['en.no']='no'
DICT['en.validation_errors.validate_domains_list']=$(cat <<-END
	Please enter domains list, separated by comma without spaces (eg domain1.tld,www.domain1.tld).
	Each domain name should consist of only letters, numbers and hyphens and contain at least one dot.
	Domains longer than 64 characters are not supported.
END
)
DICT['en.validation_errors.validate_presence']='Please enter value'
DICT['en.validation_errors.validate_absence']='Should not be specified'
DICT['en.validation_errors.validate_yes_no']='Please answer "yes" or "no"'


assert_architecture_is_valid(){
  if [[ "$(uname -m)" != "x86_64" ]]; then
    fail "$(translate errors.wrong_architecture)"
  fi
}

assert_caller_root(){
  debug 'Ensure current user is root'
  if [[ "$EUID" == "$ROOT_UID" ]]; then
    debug 'OK: current user is root'
  else
    debug 'NOK: current user is not root'
    fail "$(translate errors.must_be_root)"
  fi
  
}


assert_installed(){
  local program="${1}"
  local error="${2}"
  if ! is_installed "$program"; then
    fail "$(translate "${error}")"
  fi
}

USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE="2.12"
KEITARO_LOCK_FILEPATH="${TRACKER_ROOT}/var/install.lock"

assert_keitaro_not_installed() {
  debug 'Ensure keitaro is not installed yet'
  if is_keitaro_installed; then
    debug 'NOK: keitaro is already installed'
    print_with_color "$(translate messages.keitaro_already_installed)" 'yellow'
    clean_up
    print_url
    exit "${KEITARO_ALREADY_INSTALLED_RESULT}"
  else
    debug 'OK: keitaro is not installed yet'
  fi
}

is_keitaro_installed() {
   if isset "${VARS['installed']}"; then
     debug "installed flag is set"
     return ${SUCCESS_RESULT}
   fi
   if use_old_algorithm_for_installation_check; then
     debug "Current version is ${INSTALLED_VERSION} - using old algorithm (check '${KEITARO_LOCK_FILEPATH}' file)"
     if file_exists "${KEITARO_LOCK_FILEPATH}"; then
       return ${SUCCESS_RESULT}
     fi
   fi
   return ${FAILURE_RESULT}
}

use_old_algorithm_for_installation_check() {
  versions.lte "${INSTALLED_VERSION}" "${USE_NEW_ALGORITHM_FOR_INSTALLATION_CHECK_SINCE}"
}

assert_no_another_process_running() {

  if [[ "${KCTL_IN_KCTL}" != "" ]]; then
    return
  fi

  exec 8>/var/run/${SCRIPT_NAME}.lock

  debug "Check if another process is running"

  if flock -n -x 8; then
    debug "No other installer process is running"
  else
    fail "$(translate 'errors.already_running')" "${INTERRUPTED_ON_PARALLEL_RUN}"
  fi
}
# Check if lock file exist
#https://certbot.eff.org/docs/using.html#id5
#
assert_that_another_certbot_process_not_runing() {
  debug
  if [ -f "${CERTBOT_LOCK_FILE}" ]; then
    debug "Find lock file, raise error"
    fail "$(translate 'certbot_errors.another_proccess')"
  else
    debug "another certbot proccess not running"
  fi

}

directory_exists(){
  local directory="${1}"
  debug "Checking ${directory} directory existence"
  if [ -d "${directory}" ]; then
    debug "YES: ${directory} directory exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${directory} directory does not exist"
    return ${FAILURE_RESULT}
  fi
}

file_content_matches(){
  local file="${1}"
  local mode="${2}"
  local pattern="${3}"
  debug "Checking ${file} file matching with pattern '${pattern}'"
  if test -f "$file" && grep -q "${mode}" "$pattern" "$file"; then
    debug "YES: ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not match '${pattern}"
    return ${FAILURE_RESULT}
  fi
}

file_exists(){
  local file="${1}"
  debug "Checking ${file} file existence"
  if [ -f "${file}" ]; then
    debug "YES: ${file} file exists"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not exist"
    return ${FAILURE_RESULT}
  fi
}

arrays.index_of() {
  local value="${1}"; shift
  local array=("${@}")
  local index

  for ((index=0; index<${#array[@]}; index++)); do
    if [[ "${array[$index]}" == "${value}" ]]; then
      echo "${index}"
      return
    fi
  done
}

PATH_TO_CACHE_ROOT="${ROOT_PREFIX}/var/cache/kctl/installer"
DOWNLOADING_TRIES=10

cache.retrieve_or_download() {
  local url="${1}" skip_cache="${SKIP_CACHE:-}"
  local path msg

  cache.remove_rotten_files

  path="$(cache.path_by_url "${url}")"
  if [[ -f "${path}" ]] && [[ "${skip_cache}" == "" ]]; then
    debug "Skip downloading ${url} - got from cache"
    print_with_color "Skip downloading ${url} - got from cached ${path}" 'green'
  else
    cache.download "${url}"
  fi
}

cache.path_by_url() {
  local url="${1}"
  local url_wo_args file_name url_hash

  url_hash="$(md5sum <<< "${url}" | awk '{print $1}')"
  url_wo_args="${url%\?*}"        # http://some.site/path/to/some.file?args -> http://some.site/path/to/some.file
  file_name="${url_wo_args##*/}"  # http://some.site/path/to/some.file      -> some.file

  echo "${PATH_TO_CACHE_ROOT}/${url_hash}/${file_name}"
}

cache.purge() {
  if [[ -d "${PATH_TO_CACHE_ROOT}" ]]; then
    rm -rf "${PATH_TO_CACHE_ROOT}"
  fi
}

cache.remove_rotten_files() {
  if [[ -d "${PATH_TO_CACHE_ROOT}" ]]; then
    find "${PATH_TO_CACHE_ROOT}" -type f -mmin "+${CACHING_PERIOD_IN_MINUTES}" -delete
    find "${PATH_TO_CACHE_ROOT}" -type d -mmin "+${CACHING_PERIOD_IN_MINUTES}" -delete 2>/dev/null || true
  fi
}

cache.download() {
  local url="${1}" tries="${downloading_tries:-${DOWNLOADING_TRIES}}"
  local dir path tmp_path sleep_time connect_timeout

  debug "Downloading ${url}"
  print_with_color "Downloading ${url} " 'blue'

  path="$(cache.path_by_url "${url}")"
  tmp_path="${path}.tmp"

  dir="${path%/*}"

  mkdir -p "${dir}"

  if requests.get "${url}" "${tmp_path}" "${tries}"; then
    debug "Successfully downloaded ${url}"
    print_with_color "Successfully downloaded ${url}" 'green'

    if ! is_ci_mode || (is_ci_mode && [[ -f "${tmp_path}" ]]); then
      mv "${tmp_path}" "${path}"
    fi
  else
    fail "Couldn't download ${url}"
  fi
}

assert_upgrade_allowed() {
  if ! is_keitaro_installed; then
    echo 'Running in upgrade mode - skip checking nginx configs'
    debug "Can't upgrade because installation process is not finished yet"
    fail "$(translate errors.cant_upgrade)"
  fi
  if need_to_check_nginx_configs; then
    debug 'Running in fast upgrade mode - checking nginx configs'
    ensure_nginx_config_correct
    debug 'Everything looks good, running upgrade'
  else
    debug 'Skip checking nginx configs'
  fi
}

need_to_check_nginx_configs() {
  is_running_in_fast_upgrade_mode && [[ "${SKIP_NGINX_CHECK:-}" == "" ]]
}

ensure_nginx_config_correct() {
  if is_installed "nginx"; then
    run_command "nginx -t" "$(translate 'messages.validate_nginx_conf')" "hide_output"
  else
    if podman ps | grep -q nginx; then
      run_command "${KCTL_BIN_DIR}/kctl run nginx -t" "$(translate 'messages.validate_nginx_conf')" "hide_output"
    else
      print_with_color "Can't find running nginx container, skipping nginx config checks", 'yellow'
    fi
  fi
}

detect_installed_version(){
  if empty "${INSTALLED_VERSION}"; then
    detect_inventory_path
    if isset "${DETECTED_INVENTORY_PATH}"; then
      INSTALLED_VERSION=$(grep "^installer_version=" "${DETECTED_INVENTORY_PATH}" | sed s/^installer_version=//g)
      debug "Got installer_version='${INSTALLED_VERSION}' from ${DETECTED_INVENTORY_PATH}"
    fi
    if empty "${INSTALLED_VERSION}"; then
      debug "Couldn't detect installer_version, resetting to ${VERY_FIRST_VERSION}"
      INSTALLED_VERSION="${VERY_FIRST_VERSION}"
    fi
  fi
}

get_tracker_config_value() {
  local section="${1}"
  local parameter="${2}"
  local expression="/^\[${section}\]/ { :l /^${parameter}\s*=/ { s/.*=\s*//; p; q;}; n; b l;}"
  if file_exists "${TRACKER_CONFIG_FILE}"; then
    sed -nr "${expression}" "${TRACKER_CONFIG_FILE}" | unquote
  fi
}

get_centos_major_release() {
  grep -oP '(?<=release )\d+' /etc/centos-release
}


get_olap_db(){
  if empty "${OLAP_DB}"; then
    detect_inventory_path
    if isset "${DETECTED_INVENTORY_PATH}"; then
      OLAP_DB=$(grep "^olap_db=" "${DETECTED_INVENTORY_PATH}" | sed s/^olap_db=//g)
      debug "Got installer_version='${OLAP_DB}' from ${DETECTED_INVENTORY_PATH}"
    fi
  fi
  echo "${OLAP_DB}"
}

is_compatible_with_current_release() {
  [[ "${RELEASE_VERSION}" == "${INSTALLED_VERSION}" ]]
}

components.assert_var_is_set() {
  local component="${1}" variable="${2}" component_var value

  value="$(components.get_var "${component}" "${variable}")"

  if [[ "${value}" == "" ]]; then
    component_var="$(components.get_var_name "${component}" "${variable}")"
    fail "${component_var} is not set!"
  fi
}

components.create_group() {
  local component="${1}"
  local group group_id cmd

  group_id="$(components.get_group_id "${component}")"
  if [[ "${group_id}" != "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "group"
  group="$(components.get_var "${component}" "group")"

  cmd="groupadd --system ${group}"
  run_command "${cmd}" "  Creating group ${group}" 'hide_output'
}

components.create_user() {
  local component="${1}"
  local user group user_id home cmd

  user_id="$(components.get_user_id "${component}")"
  if [[ "${user_id}" != "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "user"
  user="$(components.get_var "${component}" "user")"

  components.assert_var_is_set "${component}" "group"
  group="$(components.get_var "${component}" "group")"

  components.assert_var_is_set "${component}" "home"
  home="$(components.get_var "${component}" "home")"

  cmd="useradd --no-create-home --system --home-dir ${home} --shell /sbin/nologin --gid ${group} ${user}"
  run_command "${cmd}" "  Creating user ${user}" 'hide_output'
}

COMPONENTS_OWN_VOLUMES_PREFIXES="/var/cache/ /var/log/ /var/lib/"

components.create_volumes() {
  local component="${1}" user group volumes 
 
  volumes="$(components.get_var "${component}" "volumes")"
  if [[ "${volumes}" == "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "user"
  user="$(components.get_var "${component}" "user")"

  components.assert_var_is_set "${component}" "group"
  group="$(components.get_var "${component}" "group")"

  for volume in ${volumes}; do
    if [[ ${volume} =~ /$ ]] && [[ ! -d ${volume} ]]; then
      components.create_volumes.create_volume_dir "${volume}" "${user}" "${group}"
    fi
  done
}

components.create_volumes.create_volume_dir() {
  local volume="${1}" user="${2}" group="${3}"

  mkdir -p "${volume}"
  for own_volume_prefix in ${COMPONENTS_OWN_VOLUMES_PREFIXES}; do
    if [[ "${volume}" =~ ^${own_volume_prefix} ]]; then
      chown "${user}:${group}" "${volume}"
    fi
  done
}

components.get_applied_var() {
  local component="${1}"
  local variable="${2}"
  local component_var

  component_var="$(components.get_var_name "${component}" "${variable}")"

  env_files.get_var "${PATH_TO_APPLIED_COMPONENTS_ENV}" "${component_var}"
}

components.get_directory() {
  local component="${1}" version

  version="$(components.get_var "${component}" 'version')"
  url="$(components.get_var "${component}" 'url')"
  url_hash="$(md5sum <<< "${url}" | awk '{print $1}')"

  echo "${KCTL_LIB}/${component}/${url_hash}/${version}"
}

components.get_group_id() {
  local component="${1}" group

  components.assert_var_is_set "${component}" "group"
  group="$(components.get_var "${component}" "group")"

  (getent group "${group}" | awk -F: '{print $3}') 2>/dev/null || true
}

components.get_keitaro_version() {
  env_files.get_var "${PATH_TO_APPLIED_COMPONENTS_ENV}" 'KEITARO_VERSION'
}

components.get_user_id() {
  local component="${1}" user

  components.assert_var_is_set "${component}" "user"
  user="$(components.get_var "${component}" "user")"

  id -u "${user}" 2>/dev/null || true
}

components.get_var() {
  local component="${1}"
  local variable="${2}"
  local component_var

  component_var="$(components.get_var_name "${component}" "${variable}")"

  env_files.read "${PATH_TO_COMPONENTS_ENV}"
  env_files.read "${PATH_TO_ENV_DIR}/components/${component}.env"

  echo "${!component_var}"
}

components.get_var_name() {
  local component="${1}"
  local var="${2}"
  local raw_component_var="${component^^}_${var^^}"
  echo "${raw_component_var//-/_}"
}

components.install() {
  local component="${1}" url version

  version="$(components.get_var "${component}" 'version')"
  debug "Installing ${component} v${version} component"
  print_with_color "Installing component ${component} v${version}" 'blue'

  components.create_group "${component}"
  components.create_user "${component}"
  components.create_volumes "${component}"
  components.pull "${component}"
}

components.install_binaries() {
  local component="${1}" version src_dir dst_dir msg

  components.preinstall "${component}"

  version="$(components.get_var "${component}" "version")"

  src_dir="$(components.get_directory "${component}")"
  dst_dir="$(components.get_var "${component}" "working_directory")"

  components.assert_var_is_set "${component}" "working_directory"

  msg="Installing ${component} v${version} from ${src_dir} to ${dst_dir}"
  debug "${msg}"; print_with_color "${msg}" 'blue'

  # shellcheck disable=SC2044
  for path_to_bin_file in $(find "${src_dir}" -maxdepth 1 -perm -u=x -type f); do
    local bin_file="${path_to_bin_file##*/}"
    local bin_file_versioned="${bin_file}-${version}"

    if [[ -f "${dst_dir}/${bin_file_versioned}" ]]; then
      msg="  Skip installing ${bin_file} - already installed"
      debug "${msg}"; print_with_color "${msg}" 'blue'
    else
      cmd="rm -f ${dst_dir}/${bin_file} ${dst_dir}/${bin_file}-*"                       # uninstall old
      cmd="${cmd} && cp ${src_dir}/${bin_file} ${dst_dir}/${bin_file_versioned}"        # install new
      cmd="${cmd} && ln -s ${dst_dir}/${bin_file_versioned} ${dst_dir}/${bin_file}"     # make symlink
      run_command "${cmd}" "  Installing ${bin_file}" "hide_output"
    fi
  done
}

components.list_all() {
  echo "${CERTBOT_COMPONENT}" 
  echo "${CERTBOT_RENEW_COMPONENT}"
  echo "${CLICKHOUSE_COMPONENT}" 
  echo "${KCTLD_COMPONENT}" 
  echo "${KCTL_CH_CONVERTER_COMPONENT}" 
  echo "${KCTL_COMPONENT}"
  echo "${MARIADB_COMPONENT}"
  echo "${NGINX_COMPONENT}"
  echo "${NGINX_STARTING_PAGE_COMPONENT}"
  echo "${REDIS_COMPONENT}"
  echo "${ROADRUNNER_COMPONENT}"
  echo "${TRACKER_COMPONENT}"
}

components.preinstall() {
  local component="${1}" url version directory cmd base_directory unpack_cmd msg

  version="$(components.get_var "${component}" 'version')"
  url="$(components.get_var "${component}" 'url')"
  directory="$(components.get_directory "${component}")"

  msg="Preinstalling component ${component} v${version} from ${url}"
  debug "${msg}"; print_with_color "${msg}" 'blue'

  if [[ "${SKIP_CACHE}" == "" ]] && [[ -d "${directory}" ]]; then
    msg="Skip preinstalling ${component} v${version} - already preinstalled to ${directory}"
    debug "${msg}"; print_with_color "  ${msg}" 'blue'
  else
    cache.retrieve_or_download "${url}"

    base_directory="${directory%/*}"
    unpack_cmd="$(components.preinstall.build_unpack_cmd "${component}" "${version}" "${url}" "${directory}")"

    cmd="rm -rf ${base_directory}/*"
    cmd="${cmd} && mkdir -p ${directory}"
    cmd="${cmd} && ${unpack_cmd}"

    run_command "${cmd}" "  Unpacking ${component} v${version} to ${directory}" "hide_output"
  fi
}

components.preinstall.build_unpack_cmd() {
  local component="${1}" version="${2}" url="${3}" directory="${4}" path
  
  path="$(cache.path_by_url "${url}")"

  if [[ "${path}" =~ \.zip$ ]]; then
    echo "unzip ${path} -d ${directory}"
  elif [[ "${path}" =~ \.tar\.gz$ ]]; then
    echo "tar -xz --no-same-owner --no-same-permissions -f ${path} -C ${directory}"
  fi
}

components.pull() {
  local component="${1}" image

  components.assert_var_is_set "${component}" "image"
  image="$(components.get_var "${component}" "image")"

  run_command "podman pull ${image}" "  Pulling ${component} image" "hide_output"
}

components.run() {
  local component="${1}" podman_extra_args="${2}"; shift 2 || true
  local image volumes_args volumes

  components.assert_var_is_set "${component}" "image"
  image="$(components.get_var "${component}" "image")"

  volumes="$(components.get_var "${component}" "volumes")"

  for volume_path in ${volumes}; do
    volumes_args="${volumes_args} -v ${volume_path}:${volume_path}"
  done

  # shellcheck disable=SC2086
  /usr/bin/podman run \
                      --rm \
                      --net host \
                      --name "${component}" \
                      --cap-add=CAP_NET_BIND_SERVICE \
                      ${volumes_args} \
                      ${podman_extra_args} \
                      "${image}" \
                      "${@}"
}

components.save_applied() {
  local msg='Saving applied env values'; debug "${msg}"; print_with_color "${msg}" 'blue'

  components.save_applied_var 'keitaro' 'version'

  for component in $(components.list_all); do
    components.save_applied_var "${component}" 'version'
    local image; image="$(components.get_var "${component}" 'image')"
    if [[ "${image}" != "" ]]; then
      components.save_applied_var "${component}" 'image'
    else
      components.save_applied_var "${component}" 'url'
    fi
  done
}

components.save_applied_var() {
  local component="${1}" variable="${2}" component_var value 

  component_var="$(components.get_var_name "${component}" "${variable}")"

  value="$(components.get_var "${component}" "${variable}")"
  env_files.forced_save_var "${PATH_TO_APPLIED_COMPONENTS_ENV}" "${component_var}" "${value}"
}

ALIVENESS_PROBES_NO=10

components.wait_until_is_up() {
  local component="${1}" msg

  if is_ci_mode || components.is_alive "${component}"; then
    return
  fi

  print_with_color "Waiting for a component ${component} to start accepting connections"  "blue"

  for ((i=0; i<ALIVENESS_PROBES_NO; i++)); do
    sleep 1
    if components.is_alive "${component}"; then
      print_with_color "Component ${component} is accepting connections"  "green"
      return
    else
      print_with_color "  Try $(( i + 1 ))/${ALIVENESS_PROBES_NO} - no connect" "yellow"
    fi
  done

  print_with_color "Component ${component} is still not accepting connections"  "red"
  return 1
}

components.is_alive() {
  local component="${1}" host port

  components.assert_var_is_set "${component}" "host"
  host="$(components.get_var "${component}" "host")"

  components.assert_var_is_set "${component}" "port"
  port="$(components.get_var "${component}" "port")"

  timeout 0.1 bash -c "</dev/tcp/${host}/${port}" &>/dev/null
}

env_files.assert_var_is_set() {
  local path_to_env_file="${1}" var_name="${2}"

  if ! env_files.has_var "${path_to_env_file}" "${var_name}"; then
    fail "Variable ${var_name} is not set in ${path_to_env_file} environment files"
  fi
}

env_files.forced_save_var() {
  local path_to_env_file="${1}" var_name="${2}" var_value="${3}"

  debug "Set ${var_name} to '$(strings.mask "${var_name}" "${var_value}")' in ${path_to_env_file}"

  if env_files.has_var "${path_to_env_file}" "${var_name}"; then
    sed -i -e "s/^${var_name}=.*/${var_name}=${var_value//\//\\/}/" "${path_to_env_file}"
  else
    echo "${var_name}=${var_value}" >> "${path_to_env_file}"
  fi
}

env_files.get_var() {
  local path_to_env_file="${1}" variable="${2^^}"

  env_files.read "${path_to_env_file}"

  echo "${!variable}"
}

env_files.has_var() {
  local path_to_env_file="${1}" env_name="${2}"
  [[ -f "${path_to_env_file}" ]] && grep -qP "^${env_name}=" "${path_to_env_file}"
}


env_files.read() {
  local path_to_env_file="${1}"

  if [[ -f "${path_to_env_file}" ]]; then
    debug "Reading env file ${path_to_env_file}"
    # shellcheck source=/dev/null
    source "${path_to_env_file}"

    if [[ "${path_to_env_file}" =~ \.env$ ]]; then 
      local path_to_local_env_file="${path_to_env_file::-4}.local.env"

      if [[ -f "${path_to_local_env_file}" ]]; then
        debug "Reading env file ${path_to_local_env_file}"
        # shellcheck source=/dev/null
        source "${path_to_local_env_file}"
      else
        debug "Couldn't read env file ${path_to_local_env_file} - file doesn't exist"
      fi
    else
      debug "Couldn't read env file ${path_to_env_file} - file doesn't exist"
    fi
  fi
}

env_files.safely_save_var() {
  local env_file_name="${1}" var_name="${2}" var_value="${3}"

  if ! env_files.has_var "${env_file_name}" "${var_name}"; then
    env_files.forced_save_var "${env_file_name}" "${var_name}" "${var_value}"
  fi
}



translate(){
  local key="${1}"
  local i18n_key="en.${key}"
  message="${DICT[$i18n_key]}"
  while isset "${2}"; do
    message=$(interpolate "${message}" "${2}")
    shift
  done
  echo "$message"
}


interpolate(){
  local string="${1}"
  local substitution="${2}"
  IFS="=" read -r name value <<< "${substitution}"
  string="${string//:${name}:/${value}}"
  echo "${string}"
}

install_package() {
  local package="${1}"
  if ! is_package_installed "${package}"; then
    debug "Installing package ${package}"
    run_command "yum install -y ${package}" "Installing ${package}" "hide_output"
  else
    debug "Package ${package} is already installed"
  fi
}

install_packages() {
  while [[ "${#}" != "0" ]]; do
    install_package "${1}"      
    shift
  done
}

is_installed(){
  local command="${1}"
  debug "Looking for command '$command'"
  if is_command_installed "${command}"; then
    debug "FOUND: Command '$command' found"
  else
    debug "NOT FOUND: Command '$command' not found"
    return ${FAILURE_RESULT}
  fi
}

is_command_installed() {
  local command="${1}"
  (is_ci_mode && sh -c "command -v '$command' -gt /dev/null") ||
    which "$command" &>/dev/null
}

is_package_installed(){
  local package="${1}"
  debug "Looking for package '$package'"
  if rpm -q --quiet "$package"; then
    debug "FOUND: Package '$package' found"
  else
    debug "NOT FOUND: Package '$package' not found"
    return ${FAILURE_RESULT}
  fi
}

upgrade_package() {
  local package="${1}"
  if is_package_installed "${package}"; then
    run_command "yum upgrade -y ${package}" "Upgrading package ${package}" "hide_output"
  else
    debug "Package ${package} is not installed"
  fi
}

detect_inventory_path(){
  debug "Detecting inventory path"
  paths=("${INVENTORY_PATH}" /root/.keitaro/installer_config .keitaro/installer_config /root/hosts.txt hosts.txt)
  for path in "${paths[@]}"; do
    if [[ -f "${path}" ]]; then
      DETECTED_INVENTORY_PATH="${path}"
      debug "Inventory found - ${DETECTED_INVENTORY_PATH}"
      return
    fi
  done
  debug "Inventory file not found"
}

add_indentation(){
  sed -r "s/^/${INDENTATION_SPACES}/g"
}

detect_mime_type(){
  local file="${1}"
  file --brief --mime-type "$file"
}
#





print_prompt(){
  local var_name="${1}"
  prompt=$(translate "prompts.$var_name")
  prompt="$(print_with_color "$prompt" 'bold')"
  if ! empty "${VARS[$var_name]}"; then
    prompt="$prompt [${VARS[$var_name]}]"
  fi
  echo -en "$prompt > "
}
print_prompt_error(){
  local error_key="${1}"
  error=$(translate "validation_errors.$error_key")
  print_with_color "*** ${error}" 'red'
}

print_prompt_help(){
  local var_name="${1}"
  print_translated "prompts.$var_name.help"
}

read_stdin(){
  if is_pipe_mode; then
    read -r -u 3 variable
  else
    read -r variable
  fi
  echo "$variable"
}

release_api.get_keitaro_version() {
  local local_keitaro_version="${1}" update_channel="${2:-}" url

  if [[ "${update_channel}" == "" ]]; then
    update_channel="$(env_files.get_var "${PATH_TO_SYSTEM_ENV}" "UPDATE_CHANNEL")" 
  fi

  url="${RELEASE_API_BASE_URL}/v2/releases/${update_channel}/latest?for_version=${local_keitaro_version}"

  cache.retrieve_or_download "${url}" >&2

  path_to_response="$(cache.path_by_url "${url}")"

  if [[ -f "${path_to_response}" ]] && jq -Mre '.version' "${path_to_response}" &> /dev/null; then
    jq -Mr '.version' "${path_to_response}"
  else
    echo "${local_keitaro_version}"
  fi
}

requests.get() {
  local url="${1}" save_to="${2:-"-"}" tries="${3:-${DOWNLOADING_TRIES}}"

  debug "Start getting ${url}"

  for ((i=1; i<tries+1; i++)); do
    local connect_timeout="$(( 2*(i-1) + 1 ))"

    debug "Try #${i}/${tries}"

    if curl -fsSL4 "${url}" --connect-timeout "${connect_timeout}" -o "${save_to}" 2>&1; then
      debug "Successfully got ${url}"
      return
    else
      debug "Error getting ${url}"

      if [[ "${i}" == "${tries}" ]]; then
        return 1 # ERROR
      fi

      sleep "${connect_timeout}"
    fi
  done
}

clean_up(){
  debug 'called clean_up()'
}

debug() {
  local message="${1}"
  echo "$message" >> "${LOG_PATH}"
  if isset "${ADDITIONAL_LOG_PATH}"; then
    echo "$message" >> "${ADDITIONAL_LOG_PATH}"
  fi
}

expand_ansible_tags_with_tag() {
  local tag="${1}"
  local tag_regex="\<${tag}\>"
  if [[ "${ANSIBLE_TAGS}" =~ ${tag_regex} ]]; then
    return
  fi
  if empty "${ANSIBLE_TAGS}"; then
    ANSIBLE_TAGS="${tag}"
  else
    ANSIBLE_TAGS="${tag},${ANSIBLE_TAGS}"
  fi
}

fail() {
  local message="${1}"
  local exit_code="${2-${FAILURE_RESULT}}"
  log_and_print_err "*** $(translate errors.program_failed) ***"
  log_and_print_err "$message"
  print_err
  if [[ "${exit_code}" != "${INTERRUPTED_ON_PARALLEL_RUN}" ]]; then
    clean_up
  fi
  exit "${exit_code}"
}

common_parse_options(){
  local option="${1}"
  local argument="${2}"
  case $option in
    l|L)
      print_deprecation_warning '-L option is ignored'
      ;;
    v)
      version
      ;;
    h)
      help
      ;;
    *)
      wrong_options
      ;;
  esac
}


help(){
  usage_en_header
  help_en
  help_en_common
  help_en_variables
  exit ${SUCCESS_RESULT}
}


usage(){
  usage_en
  exit ${FAILURE_RESULT}
}


version(){
  echo "${SCRIPT_NAME} v${RELEASE_VERSION}"
  exit ${SUCCESS_RESULT}
}


wrong_options(){
  WRONG_OPTIONS="wrong_options"
}


ensure_options_correct(){
  if isset "${WRONG_OPTIONS}"; then
    usage
  fi
}


usage_en(){
  usage_en_header
  echo "Try '${SCRIPT_NAME} -h' for more information."
  echo
}

usage_en_header(){
  echo "Usage: ${SCRIPT_NAME} [OPTION]..."
  echo
}

help_en_common(){
  echo "Miscellaneous:"
  echo "  -h                       display this help text and exit"
  echo
  echo "  -v                       display version information and exit"
  echo
}

help_en_variables(){
  echo  "Environment variables:"
  echo 
  echo  "  TRACKER_STABILITY       Set up stability channel stable|unstsable. Default: stable"
  echo
}

init() {
  init_kctl
  debug "Starting init stage: log basic info"
  debug "Command: ${SCRIPT_NAME} ${TOOL_ARGS}"
  debug "Script version: ${RELEASE_VERSION}"
  debug "User ID: ${EUID}"
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGTERM
  trap on_exit_by_user_interrupt SIGINT
}

LOGS_TO_KEEP=5

is_logging_to_file() {
  [[ ! "${LOG_PATH}" =~ ^/dev/ ]]
}

init_kctl() {
  init_kctl_dirs_and_links
  if is_logging_to_file; then
    init_log "${LOG_PATH}"
  fi
}

init_kctl_dirs_and_links() {
  if [[ ! -d "${KCTL_ROOT}" ]]; then
    if ! create_kctl_dirs_and_links; then
      echo "Can't create keitaro directories" >&2
      exit 1
    fi
  fi
  if [[ ! -d "${WORKING_DIR}" ]]; then
    if ! mkdir -p "${WORKING_DIR}"; then
      echo "Can't create keitaro working directory ${WORKING_DIR}" >&2
      exit 1
    fi
  fi
}

create_kctl_dirs_and_links() {
  mkdir -p "${LOG_DIR}" "${SSL_LOG_DIR}" "${INVENTORY_DIR}" "${KCTL_BIN_DIR}" "${WORKING_DIR}" &&
    chmod 0750 "${ETC_DIR}" &&
    ln -s "${ETC_DIR}" "${KCTL_ETC_DIR}" &&
    ln -s "${LOG_DIR}" "${KCTL_LOG_DIR}" &&
    ln -s "${WORKING_DIR}" "${KCTL_WORKING_DIR}"
}

init_log() {
  local log_path="${1}"
  save_previous_log "${log_path}"
  delete_old_logs "${log_path}"
  create_log "${log_path}"
}

save_previous_log() {
  local log_path="${1}"
  local previous_log_timestamp
  if [[ -f "${log_path}" ]]; then
    previous_log_timestamp=$(date -r "${log_path}" +"%Y%m%d%H%M%S")
    mv "${log_path}" "${log_path}-${previous_log_timestamp}"
  fi
}

delete_old_logs() {
  local log_filepath="${1}"
  local log_dir
  local log_filename
  log_dir="$(dirname "${log_filepath}")"
  log_filename="$(basename "${log_filepath}")"
  /usr/bin/find "${log_dir}" -name "${log_filename}-*" | \
    /usr/bin/sort | \
    /usr/bin/head -n -${LOGS_TO_KEEP} | \
    /usr/bin/xargs rm -f
}

create_log() {
  local log_path="${1}"
  if [[ "${TOOL_NAME}" == "install" ]] && ! is_ci_mode; then
    (umask 066 && touch "${log_path}")
  else
    touch "${log_path}"
  fi
}

log_and_print_err(){
  local message="${1}"
  print_err "$message" 'red'
  debug "$message"
}

on_exit(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')"
}

on_exit_by_user_interrupt(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')" "${INTERRUPTED_BY_USER_RESULT}"
}

print_content_of(){
  local filepath="${1}"
  if [ -f "$filepath" ]; then
    if [ -s "$filepath" ]; then
      echo "Content of '${filepath}':"
      cat "$filepath" | add_indentation
    else
      debug "File '${filepath}' is empty"
    fi
  else
    debug "Can't show '${filepath}' content - file does not exist"
  fi
}
print_deprecation_warning() {
  local message="${1}"
  print_err "DEPRECATION WARNING: ${message}" "yellow"
}

print_err(){
  local message="${1}"
  local color="${2}"
  print_with_color "$message" "$color" >&2
}

print_translated(){
  local key="${1}"
  message=$(translate "${key}")
  if ! empty "$message"; then
    echo "$message"
  fi
}

declare -A COLOR_CODE

COLOR_CODE['bold']=1

COLOR_CODE['default']=39
COLOR_CODE['red']=31
COLOR_CODE['green']=32
COLOR_CODE['yellow']=33
COLOR_CODE['blue']=34
COLOR_CODE['magenta']=35
COLOR_CODE['cyan']=36
COLOR_CODE['grey']=90
COLOR_CODE['light.red']=91
COLOR_CODE['light.green']=92
COLOR_CODE['light.yellow']=99
COLOR_CODE['light.blue']=94
COLOR_CODE['light.magenta']=95
COLOR_CODE['light.cyan']=96
COLOR_CODE['light.grey']=37

RESET_FORMATTING='\e[0m'

print_with_color(){
  local message="${1}"
  local color="${2}"
  if [[ "$color" != "" ]]; then
    escape_sequence="\e[${COLOR_CODE[$color]}m"
    echo -e "${escape_sequence}${message}${RESET_FORMATTING}"
  else
    echo "$message"
  fi
}

REMOVE_COLORS_SED_REGEX="s/\x1b\[([0-9]{1,3}(;[0-9]{1,3}){,2})?[mGK]//g"

run_command(){
  local command="${1}"
  local message="${2}"
  local hide_output="${3}"
  local allow_errors="${4}"
  local run_as="${5}"
  local print_fail_message_method="${6}"
  local output_log="${7}"
  debug "Evaluating command: ${command}"
  if empty "$message"; then
    run_command_message=$(print_with_color "$(translate 'messages.run_command')" 'blue')
    message="$run_command_message \`$command\`"
  else
    message=$(print_with_color "${message}" 'blue')
  fi
  if isset "$hide_output"; then
    echo -en "${message} . "
  else
    echo -e "${message}"
  fi
  really_run_command "${command}" "${hide_output}" "${allow_errors}" "${run_as}" \
                     "${print_fail_message_method}" "${output_log}"
}


print_command_status(){
  local command="${1}"
  local status="${2}"
  local color="${3}"
  local hide_output="${4}"
  debug "Command result: ${status}"
  if isset "$hide_output"; then
    if [[ "$hide_output" =~ (uncolored_yes_no) ]]; then
      print_uncolored_yes_no "$status"
    else
      print_with_color "$status" "$color"
    fi
  fi
}


print_uncolored_yes_no(){
  local status="${1}"
  if [[ "$status" == "NOK" ]]; then
    echo "NO"
  else
    echo "YES"
  fi
}



really_run_command(){
  local command="${1}"
  local hide_output="${2}"
  local allow_errors="${3}"
  local run_as="${4}"
  local print_fail_message_method="${5}"
  local output_log="${6}"
  local evaluated_command
  local current_command_script
  current_command_script=$(save_command_script "${command}" "${run_as}")
  evaluated_command=$(command_run_as "${current_command_script}" "${run_as}")
  evaluated_command=$(unbuffer_streams "${evaluated_command}")
  evaluated_command=$(save_command_logs "${evaluated_command}" "${output_log}")
  evaluated_command=$(hide_command_output "${evaluated_command}" "${hide_output}")
  debug "Real command: ${evaluated_command}"
  if ! eval "${evaluated_command}"; then
    print_command_status "${command}" 'NOK' 'red' "${hide_output}"
    if isset "$allow_errors"; then
      remove_current_command "$current_command_script"
      return ${FAILURE_RESULT}
    else
      fail_message=$(print_current_command_fail_message "$print_fail_message_method" "$current_command_script")
      remove_current_command "$current_command_script"
      fail "${fail_message}"
    fi
  else
    print_command_status "$command" 'OK' 'green' "$hide_output"
    remove_current_command "$current_command_script"
  fi
}


command_run_as(){
  local command="${1}"
  local run_as="${2}"
  if isset "$run_as"; then
    echo "sudo -u '${run_as}' bash -c '${command}'"
  else
    echo "bash ${command}"
  fi
}


unbuffer_streams(){
  local command="${1}"
  echo "stdbuf -i0 -o0 -e0 ${command}"
}


save_command_logs(){
  local evaluated_command="${1}"
  local output_log="${2}"
  local remove_colors="sed -r -e '${REMOVE_COLORS_SED_REGEX}'"
  save_output_log="tee -i ${CURRENT_COMMAND_OUTPUT_LOG} | tee -ia >(${remove_colors} >> ${LOG_PATH})"
  save_error_log="tee -i ${CURRENT_COMMAND_ERROR_LOG} | tee -ia >(${remove_colors} >> ${LOG_PATH})"
  if isset "${output_log}"; then
    save_output_log="${save_output_log} | tee -ia ${output_log}"
    save_error_log="${save_error_log} | tee -ia ${output_log}"
  fi
  echo "((${evaluated_command}) 2> >(${save_error_log}) > >(${save_output_log}))"
}


remove_colors_from_file(){
  local file="${1}"
  debug "Removing colors from file ${file}"
  sed -r -e "${REMOVE_COLORS_SED_REGEX}" -i "$file"
}


hide_command_output(){
  local command="${1}"
  local hide_output="${2}"
  if isset "$hide_output"; then
    echo "${command} > /dev/null"
  else
    echo "${command}"
  fi
}


save_command_script(){
  local command="${1}"
  local run_as="${2}"
  local current_command_dir
    current_command_dir=$(mktemp -d)
  if isset "$run_as"; then
    chown "$run_as" "$current_command_dir"
  fi
  local current_command_script="${current_command_dir}/${CURRENT_COMMAND_SCRIPT_NAME}"
  echo '#!/usr/bin/env bash' > "${current_command_script}"
  echo 'set -o pipefail' >> "${current_command_script}"
  echo -e "${command}" >> "${current_command_script}"
  debug "$(print_content_of "${current_command_script}")"
  echo "${current_command_script}"
}


print_current_command_fail_message(){
  local print_fail_message_method="${1}"
  local current_command_script="${2}"
  remove_colors_from_file "${CURRENT_COMMAND_OUTPUT_LOG}"
  remove_colors_from_file "${CURRENT_COMMAND_ERROR_LOG}"
  if empty "$print_fail_message_method"; then
    print_fail_message_method="print_common_fail_message"
  fi
  local fail_message
  local fail_message_header
  fail_message_header=$(translate 'errors.run_command.fail')
  fail_message=$(eval "$print_fail_message_method" "$current_command_script")
  echo -e "${fail_message_header}\n${fail_message}"
}


print_common_fail_message(){
  local current_command_script="${1}"
  print_content_of "${current_command_script}"
  print_tail_content_of "${CURRENT_COMMAND_OUTPUT_LOG}"
  print_tail_content_of "${CURRENT_COMMAND_ERROR_LOG}"
}


print_tail_content_of(){
  local file="${1}"
  print_content_of "${file}" |  tail -n 20
}


remove_current_command(){
  local current_command_script="${1}"
  debug "Removing current command script and logs"
  rm -f "$CURRENT_COMMAND_OUTPUT_LOG" "$CURRENT_COMMAND_ERROR_LOG" "$current_command_script"
  rmdir "$(dirname "$current_command_script")"
}

PATH_TO_NGINX_PIDFILE="/var/run/nginx.pid"

start_or_reload_nginx(){
  if podman exec nginx test -f "${PATH_TO_NGINX_PIDFILE}" || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "systemctl reload nginx" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
  fi
}

system.users.create() {
  local user="${1}" home_dir="${2}" cmd

  if ! getent passwd "${user}" > /dev/null; then
    cmd="/usr/sbin/useradd --create-home --home-dir ${home_dir} --user-group --shell /bin/bash ${user}"
    run_command "${cmd}" "Creating user ${user}" 'hide_output'
  fi
}

systemd.disable_and_stop_service() {
  local name="${1}"
  systemd.disable_service "${name}"
  systemd.stop_service "${name}"
}

systemd.disable_service() {
  local name="${1}"
  local command="systemctl disable ${name}"
  run_command "${command}" "Disabling SystemD service ${name}" "hide_output"
}

systemd.enable_and_start_service() {
  local name="${1}"
  systemd.enable_service "${name}"
  systemd.start_service "${name}"
}

systemd.enable_service() {
  local name="${1}"
  local command="systemctl enable ${name}"
  run_command "${command}" "Enabling SystemD service ${name}" "hide_output"
}

systemd.reload_service() {
  local name="${1}"
  local command="systemctl reload ${name}"
  run_command "${command}" "Reloading SystemD service ${name}" "hide_output"
}

systemd.restart_service() {
  local name="${1}"
  local command="systemctl restart ${name}"
  run_command "${command}" "Restarting SystemD service ${name}" "hide_output"
}

systemd.start_service() {
  local name="${1}"
  local command="systemctl start ${name}"
  run_command "${command}" "Starting SystemD service ${name}" "hide_output"
}

systemd.stop_service() {
  local name="${1}"
  local command="systemctl stop ${name}"
  run_command "${command}" "Stopping SystemD service ${name}" "hide_output"
}

systemd.update_units() {
  run_command 'systemctl daemon-reload' "Updating SystemD units" "hide_output"
}

tracker.get_update_channel() {
  local is_beta_channel

  if LOG_PATH=/dev/null kctl run cli-php system:get_setting is_beta_channel &>/dev/null; then
    is_beta_channel="$(LOG_PATH=/dev/null kctl run cli-php system:get_setting is_beta_channel)"
    debug "Got tracker setting is_beta_channel - '${is_beta_channel}'"

    if [[ "${is_beta_channel}" == "1" ]]; then
      echo "${UPDATE_CHANNEL_BETA}"
    elif [[ "${is_beta_channel}" == "0" ]]; then
      echo "${UPDATE_CHANNEL_STABLE}"
    elif [[ "${is_beta_channel}" == "" ]]; then
      echo "${UPDATE_CHANNEL_STABLE}"
    fi
  fi
}

TRACKER_VERSION_PHP="${TRACKER_ROOT}/version.php"

tracker.get_version() {
  if [[ -f "${TRACKER_VERSION_PHP}" ]]; then
    cut -d "'" -f 2 "${TRACKER_VERSION_PHP}"
  fi
}

generate_password(){
  local PASSWORD_LENGTH=16
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c${PASSWORD_LENGTH}
}
generate_uuid() {
  uuidgen | tr -d '-'
}

join_by(){
  local delimiter=$1
  shift
  echo -n "$1"
  shift
  printf "%s" "${@/#/${delimiter}}"
}

strings.mask() {
  local var_name="${1}" var_value="${2}"
  if [[ "${var_name}" =~ passw ]]; then
    echo "***MASKED***"
  else
    echo "${var_value}"
  fi
}

to_lower(){
  local string="${1}"
  echo "${string,,}"
}

unquote() {
  sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
}


ensure_valid() {
  local option="${1}"
  local var_name="${2}"
  local validation_methods="${3}"
  error="$(get_error "${var_name}" "${validation_methods}")"
  if isset "$error"; then
    print_err "-${option}: $(translate "validation_errors.${error}" "value=${VARS[$var_name]}")"
    exit "${FAILURE_RESULT}"
  fi
}

get_error(){
  local var_name="${1}"
  local validation_methods_string="${2}"
  local value="${VARS[$var_name]}"
  local error=""
  read -ra validation_methods <<< "$validation_methods_string"
  for validation_method in "${validation_methods[@]}"; do
    if ! eval "${validation_method} '${value}'"; then
      debug "${var_name}: '${value}' invalid for ${validation_method} validator"
      error="${validation_method}"
      break
    else
      debug "${var_name}: '${value}' valid for ${validation_method} validator"
    fi
  done
  echo "${error}"
}


validate_absence(){
  local value="${1}"
  empty "$value"
}

validate_alnumdashdot(){
  local value="${1}"
  [[ "$value" =~  ^([0-9A-Za-z_\.\-]+)$ ]]
}

validate_directory_existence(){
  local value="${1}"
  [[ -d "$value" ]]
}
SUBDOMAIN_REGEXP="[[:alnum:]-]+"
DOMAIN_REGEXP="(${SUBDOMAIN_REGEXP}\.)+[[:alpha:]]${SUBDOMAIN_REGEXP}"
MAX_DOMAIN_LENGTH=64
DOMAIN_LENGTH_REGEXP="[^,]{1,${MAX_DOMAIN_LENGTH}}"

validate_domain(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_REGEXP}$ ]] && [[ "$value" =~ ^${DOMAIN_LENGTH_REGEXP}$ ]]
}
DOMAIN_LIST_REGEXP="${DOMAIN_REGEXP}(,${DOMAIN_REGEXP})*"
DOMAIN_LIST_LENGTH_REGEXP="${DOMAIN_LENGTH_REGEXP}(,${DOMAIN_LENGTH_REGEXP})*"


validate_domains_list(){
  local value="${1}"
  [[ "$value" =~ ^${DOMAIN_LIST_REGEXP}$ ]] && [[ "${value}" =~ ^${DOMAIN_LIST_LENGTH_REGEXP}$ ]]
}

validate_enough_space_for_dump() {
  local file="${1}"
  local dump_size_in_kb
  local needed_space_in_kb
  local available_space_in_mb
  local available_space_in_kb
  local unpacked_dump_size_in_kb

  if empty "$file"; then
    return ${SUCCESS_RESULT}
  fi
  dump_size_in_kb=$(du -k "$file" | cut -f1)
  available_space_in_mb=$(get_free_disk_space_mb)
  available_space_in_kb=$((available_space_in_mb * 1024))

  if file --mime-type "$file" | grep -q gzip$; then
    unpacked_dump_size_in_kb=$((dump_size_in_kb * 7))
    needed_space_in_kb=$((unpacked_dump_size_in_kb * 25 / 10))
  else
    needed_space_in_kb=$((dump_size_in_kb * 15 / 10))
  fi

  if [[ "$needed_space_in_kb" -gt "$available_space_in_kb" ]]; then
    return ${FAILURE_RESULT}
  else
    return ${SUCCESS_RESULT}
  fi
}
#





validate_file_existence(){
  local value="${1}"
  if empty "$value"; then
    return ${SUCCESS_RESULT}
  fi
  [[ -f "$value" ]]
}

validate_not_reserved_word(){
  local value="${1}"
  [[ "$value" !=  'yes' ]] && [[ "$value" != 'no' ]] && [[ "$value" != 'true' ]] && [[ "$value" != 'false' ]]
}

validate_not_root(){
  local value="${1}"
  [[ "$value" !=  'root' ]]
}


validate_presence(){
  local value="${1}"
  isset "$value"
}

validate_starts_with_latin_letter(){
  local value="${1}"
  [[ "$value" =~  ^[A-Za-z] ]]
}

versions.cmp() {
  local version1="${1}" version2="${2}" segments1 segments2 i

  version1="$(versions.normalize "${version1}")"
  version2="$(versions.normalize "${version2}")"

  declare -a segments1="(${version1//./ })"
  declare -a segments2="(${version2//./ })"

  if [[ "${#segments1[@]}" -gt "${#segments2[@]}" ]]; then
    local length="${#segments1[@]}"
  else
    local length="${#segments2[@]}"
  fi

  for ((i=0; i<length; i++)); do
    local cmp; cmp="$(versions.cmp_segment "${segments1[${i}]}" "${segments2[${i}]}")"

    if [[ "${cmp}" != "0" ]]; then
      echo "${cmp}"
      return
    fi
  done

  echo "0"
}

versions.cmp_segment() {
  local segment1="${1:-0}" segment2="${2:-0}"

  if [[ "${segment1}" == "${segment2}" ]]; then
    echo "0"
    return
  fi

  if [[ "${segment1}" =~ [[:digit:]] ]] && [[ "${segment2}" =~ [[:digit:]] ]]; then
    if [[ "${segment1}" -gt "${segment2}" ]]; then
      echo "1"
      return
    fi

    if [[ "${segment1}" -lt "${segment2}" ]]; then
      echo "-1"
      return
    fi

    echo "0"
    return
  fi

  if [[ "${segment1}" =~ [[:digit:]] ]]; then
    echo "1"
    return
  fi

  if [[ "${segment2}" =~ [[:digit:]] ]]; then
    echo "-1"
    return
  fi

  # all segments are symbolic
  local index1; index1="$(arrays.index_of "${segment1}" "${UPDATE_CHANNELS[@]}")"
  local index2; index2="$(arrays.index_of "${segment2}" "${UPDATE_CHANNELS[@]}")"

  versions.cmp_segments "${index1}" "${index2}"
}

versions.eq() {
  local cmp; cmp="$(versions.cmp "${1}" "${2}")"

  [[ "${cmp}" -eq "0" ]]
}

versions.gt() {
  local cmp; cmp="$(versions.cmp "${1}" "${2}")"

  [[ "${cmp}" -gt "0" ]]
}

versions.gte() {
  ! versions.lt "${1}" "${2}"
}

versions.lt() {
  local cmp; cmp="$(versions.cmp "${1}" "${2}")"

  [[ "${cmp}" -lt "0" ]]
}

versions.lte() {
  ! versions.gt "${1}" "${2}"
}

versions.ne() {
  ! versions.eq "${1}" "${2}"
}

versions.normalize() {
  local version="${1}" normalized_version channels="${UPDATE_CHANNELS[*]}" channel_re
 
  # downcase string, so 10.1-ALPHA -> 10.1-alpha
  normalized_version="${version,,}"

  # downcase string, so 10.1-ALPHA -> 10.1-alpha
  normalized_version="${normalized_version,,}"

  # build channel RE
  channel_re="(.*)(${channels// /|})(.*)"
  if [[ "${normalized_version}" =~ ${channel_re} ]]; then
    # surround channel name with dots, so 10.1beta1 -> 10.beta.1
    normalized_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi

  # change dashes to dots, so 10.1-beta -> 10.1.beta
  normalized_version="${normalized_version//-/.}"

  while [[ "${normalized_version}" =~ \.\. ]]; do
    # remove double dots, so 10..1 -> 10.1
    normalized_version="${normalized_version//../.}"
  done

  # remove dot in the end, so 10.1. -> 10.1
  normalized_version="${normalized_version%%.}"

  if [[ "${normalized_version: -1}" =~ [[:alpha:]] ]]; then
    normalized_version="${normalized_version}.0"
  fi

  echo "${normalized_version}"
}

versions.patch() {
  local version="${1}" length i

  version="$(versions.normalize "${version}")"

  declare -a segments="(${version//./ })"

  if [[ "${segments[2]}" =~ [[:alpha:]] ]]; then
    length=4
  else
    length=3
  fi 

  printf "%s" "${segments[0]}"

  for ((i=1; i<length; i++)); do
    if [[ "${segments[$i]}" != "" ]]; then
      printf ".%s" "${segments[$i]}"
    else
      printf ".0"
    fi
  done
}

versions.sort() {
  local i j length
  readarray -t versions

  length="${#versions[@]}"

  for ((i=0; i<length-1; i++)); do
    for ((j=i+1; j<length; j++)); do
      if versions.gt "${versions[$i]}" "${versions[$j]}"; then
        local tmp="${versions[$i]}"
        versions[$i]="${versions[$j]}"
        versions[$j]="${tmp}"
      fi
    done
  done

  for ((i=0; i<length; i++)); do
    echo "${versions[$i]}"
  done
}

is_no(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(no|n|нет|н)$ ]]
}

is_yes(){
  local answer="${1}"
  shopt -s nocasematch
  [[ "$answer" =~ ^(yes|y|да|д)$ ]]
}

transform_to_yes_no(){
  local var_name="${1}"
  if is_yes "${VARS[$var_name]}"; then
    debug "Transform ${var_name}: ${VARS[$var_name]} => yes"
    VARS[$var_name]='yes'
  else
    debug "Transform ${var_name}: ${VARS[$var_name]} => no"
    VARS[$var_name]='no'
  fi
}
validate_yes_no(){
  local value="${1}"
  (is_yes "$value" || is_no "$value")
}


KCTL_LIB="${ROOT_PREFIX}/var/lib/kctl"
PACKAGED_TRACKERS_ROOT="${KCTL_LIB}/tracker"
KEITARO_ALREADY_INSTALLED_RESULT=0

SERVER_IP=""

INSTALLED_VERSION=""

CERTBOT_COMPONENT="certbot"
CERTBOT_RENEW_COMPONENT="certbot-renew"
CLICKHOUSE_COMPONENT="clickhouse"
KCTLD_COMPONENT="kctld"
KCTL_CH_CONVERTER_COMPONENT="kctl-ch-converter"
KCTL_COMPONENT="kctl"
MARIADB_COMPONENT="mariadb"
NGINX_COMPONENT="nginx"
NGINX_STARTING_PAGE_COMPONENT="nginx"
REDIS_COMPONENT="redis"
ROADRUNNER_COMPONENT="roadrunner"
TRACKER_COMPONENT="tracker"

DICT['en.messages.keitaro_already_installed']='Keitaro is already installed'
DICT['en.messages.validate_nginx_conf']='Checking nginx config'
DICT['en.messages.successful_install']='Keitaro has been installed!'
DICT['en.messages.successful_upgrade']='Keitaro has been upgraded!'
DICT['en.messages.visit_url']="Please open the link in your browser of choice:"
DICT['en.errors.wrong_distro']='The installer is not compatible with this operational system. Please reinstall this server with "CentOS 9 Stream"'
DICT['en.errors.not_enough_ram']='The size of RAM on your server should be at least 2 GB'
DICT['en.errors.not_enough_free_disk_space']='The free disk space on your server must be at least 2 GB.'
DICT['en.errors.keitaro_dump_invalid']='SQL dump is broken'
DICT['en.errors.isp_manager_installed']='You can not install Keitaro on the server with ISP Manager installed. Please run this program on a clean CentOS server.'
DICT['en.errors.vesta_cp_installed']='You can not install Keitaro on the server with Vesta CP installed. Please run this program on a clean CentOS server.'
DICT['en.errors.apache_installed']='You can not install Keitaro on the server with Apache HTTP server installed. Please run this program on a clean CentOS server.'
DICT['en.errors.systemctl_doesnt_work_properly']="You can not install Keitaro on the server where systemctl doesn't work properly. Please run this program on another CentOS server."
DICT['en.errors.cant_detect_server_ip']="The installer couldn't detect the server IP address, please contact Keitaro support team"
DICT['en.errors.already_running']="Another installation process is already running"

DICT['en.prompts.db_restore_path']='Please enter the path to the SQL dump file'
DICT['en.prompts.salt']='Please enter "salt" parameter (see old application/config/config.ini.php)'
DICT['en.welcome']='This installer will guide you through the steps required to install Keitaro on your server.'
DICT['en.validation_errors.validate_alnumdashdot']='Only Latin letters, numbers, dashes, underscores and dots allowed'
DICT['en.validation_errors.validate_file_existence']='The file was not found by the specified path, please enter the correct path to the file'
DICT['en.validation_errors.validate_enough_space_for_dump']='Dont enough space for restore dump'
DICT['en.validation_errors.validate_not_reserved_word']='You are not allowed to use yes/no/true/false as value'
DICT['en.validation_errors.validate_starts_with_latin_letter']='The value must begin with a Latin letter'


get_ansible_galaxy_command() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "LC_ALL=C ansible-galaxy-3"
  else
    echo "LC_ALL=C.UTF-8 ansible-galaxy"
  fi
}
install_ansible_collection() {
  local collection="${1}"
  local package="${collection//\./-}.tar.gz"
  local collection_url="${FILES_KEITARO_ROOT_URL}/scripts/ansible-galaxy-collections/${package}"
  local cmd

  if ! is_ansible_collection_installed "${collection}"; then
    cmd="$(get_ansible_galaxy_command) collection install ${collection_url} --force"
    run_command "${cmd}" "Installing ansible galaxy collection ${collection}" "hide"
  fi
}

is_ansible_collection_installed() {
  local collection="${1}"
  [[ -d "/root/.ansible/collections/ansible_collections/${collection//.//}" ]]
}

get_ansible_package_name() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "ansible-python3"
  else
    echo "ansible-core"
  fi
}

get_free_disk_space_mb() {
  (df -m --output=avail / | tail -n1) 2>/dev/null
}

get_config_value(){
  local var="${1}"
  local file="${2}"
  local separator="${3}"
  if file_exists "${file}"; then
    grep "^${var}\\b" "${file}" | \
      grep "${separator}" | \
      head -n1 | \
      awk -F"${separator}" '{print $2}' | \
      awk '{$1=$1; print}' | \
      unquote
  fi
}

# If installed version less than or equal to version from array value
# then ANSIBLE_TAGS will be expanded by appropriate tags (given from array key)
# Example:
#   when REPLAY_ROLE_TAGS_ON_UPGRADE_FROM=( ['init']='1.0' ['enable-swap']='2.0' )
#     and insalled version is 2.0
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `enable-swap` tag
declare -A REPLAY_ROLE_TAGS_SINCE=(
  ['apply-hot-fixes']='2.35.3'
  ['create-user-and-dirs']='2.38.2'
  ['disable-selinux']='2.25.0'
  ['install-chrony']='2.27.7'
  ['install-fail2ban']='2.39.24'
  ['install-firewalld']='2.29.15'
  ['install-packages']='2.27.7'
  ['install-postfix']='2.29.8'
  ['setup-journald']='2.32.0'
  ['setup-root-home']="2.37.4"
  ['setup-timezone']='0.9'
  ['tune-swap']='2.39.27'
  ['tune-sysctl']='2.39.31'

  ['install-clickhouse']='2.43.4'
  ['install-mariadb']='2.41.10'
  ['install-redis']='2.41.10'

  ['tune-nginx']='2.43.4'

  ['install-php']='2.30.10'
  ['tune-php']='2.38.2'
  ['tune-roadrunner']='2.41.10'
  ['tune']='2.42.9'
)

expand_ansible_tags_on_upgrade() {
  if [[ "${RUNNING_MODE}" != "${RUNNING_MODE_UPGRADE}" ]] ; then
    return
  fi
  debug "Upgrade mode detected, expading ansible tags."
  local installed_version
  installed_version=$(get_installed_version_on_upgrade)
  debug "Upgrading ${installed_version} -> ${RELEASE_VERSION}"
  expand_ansible_tags_with_upgrade_tag
  expand_ansible_tags_with_tune_tag_on_changing_ram_size
  expand_ansible_tags_with_role_tags "${installed_version}"
  debug "ANSIBLE_TAGS is set to ${ANSIBLE_TAGS}"
}

expand_ansible_tags_with_upgrade_tag() {
  expand_ansible_tags_with_tag "upgrade"
  if is_upgrading_mode_full; then
    expand_ansible_tags_with_tag "full-upgrade"
  fi
}

expand_ansible_tags_with_tune_tag_on_changing_ram_size() {
  if isset "${VARS['ram_size_mb_changed']}"; then
    debug 'RAM size was changed recently, force tuning'
    expand_ansible_tags_with_tag "tune"
  else
    debug 'RAM size is not changed recently'
  fi
}

expand_ansible_tags_with_role_tags() {
  local installed_version=${1}
  for role_tag in "${!REPLAY_ROLE_TAGS_SINCE[@]}"; do
    replay_role_tag_since=${REPLAY_ROLE_TAGS_SINCE[${role_tag}]}
    if versions.lte "${installed_version}" "${replay_role_tag_since}"; then
      expand_ansible_tags_with_tag "${role_tag}"
    fi
  done
}

get_installed_version_on_upgrade() {
  if is_upgrading_mode_full; then
    debug "Upgrading mode is 'full', simulating upgrade from ${VERY_FIRST_VERSION}"
    echo ${VERY_FIRST_VERSION}
  else
    echo "${INSTALLED_VERSION}"
  fi
}

is_upgrading_mode_full() {
  [[ "${UPGRADING_MODE}" == "${UPGRADING_MODE_FULL}" ]]
}

clean_up() {
  popd &> /dev/null || true
}

is_running_in_upgrade_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_UPGRADE}" ]]
}

is_running_in_install_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_INSTALL}" ]]
}

is_running_in_fast_upgrade_mode() {
  is_running_in_upgrade_mode && [[ "${UPGRADING_MODE}" == "${UPGRADING_MODE_FAST}" ]]
}

is_running_in_full_upgrade_mode() {
  is_running_in_upgrade_mode && [[ "${UPGRADING_MODE}" == "${UPGRADING_MODE_FULL}" ]]
}

is_running_in_rescue_mode() {
  is_running_in_full_upgrade_mode
}


get_ram_size_mb() {
  (free -m | grep Mem: | awk '{print $2}') 2>/dev/null
}

RUNNING_MODE_INSTALL="install"
RUNNING_MODE_UPGRADE="upgrade"
RUNNING_MODE="${RUNNING_MODE_INSTALL}"

UPGRADING_MODE_FAST="fast"
UPGRADING_MODE_FULL="full"
UPGRADING_MODE="${UPGRADING_MODE_FAST}"

parse_options(){
  while getopts ":RCUF:S:a:t:i:wo:L:WrK:A:k:l:hvs" option; do
    local option_value="${OPTARG}"
    ARGS["${option}"]="${option_value}"
    case "${option}" in
      C)
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        UPGRADING_MODE="${UPGRADING_MODE_FULL}"
        ;;
      U)
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        ;;
      t)
        print_deprecation_warning '-t option will be removed soon, use ANSIBLE_TAGS var to specify the tags'
        ANSIBLE_TAGS="${option_value}"
        ;;
      i)
        print_deprecation_warning '-i option will be removed soon, use ANSIBLE_IGNORE_TAGS var to specify the ignored tags'
        ANSIBLE_IGNORE_TAGS="${option_value}"
        ;;
      w)
        print_deprecation_warning '-w option will be removed soon, use WITHOUT_YUM_UPDATE var to skip yum update'
        WITHOUTH_YUM_UPDATE="true"
        ;;
      o)
        print_deprecation_warning '-o option will be removed soon, use LOG_PATH var to specify path to log file'
        LOG_PATH="${option_value}"
        ;;
      a)
        fail '-a is unsupported, use TRACKER_VERSION or TRACKER_URL to specify the package'
        ;;
      W)
        print_deprecation_warning '-W option will be removed soon, you can safely omit it'
        RUNNING_MODE="${RUNNING_MODE_INSTALL}"
        ;;
      r)
        print_deprecation_warning '-r option will be removed soon, use -U instead'
        RUNNING_MODE="${RUNNING_MODE_UPGRADE}"
        if [[ "${ANSIBLE_TAGS}" =~ full-upgrade ]]; then
          UPGRADING_MODE="${UPGRADING_MODE_FULL}"
        fi
        ;;
      R)
        # shellcheck disable=SC2016
        fail '-R option is unsupported. Install tracker and use `kctl transfers restore-from-sql` to restore'
        ;;
      F)
        # shellcheck disable=SC2016
        fail '-F option is unsupported. Install tracker and use `kctl transfers restore-from-sql` to restore'
        ;;
      S)
        # shellcheck disable=SC2016
        fail '-S option is unsupported. Install tracker and use `kctl transfers restore-from-sql` to restore'
        ;;
      L)
        print_deprecation_warning '-l option is ignored'
        ;;
      K)
        print_deprecation_warning '-K option is ignored'
        ;;
      A)
        print_deprecation_warning '-A option is ignored'
        ;;
      k)
        print_deprecation_warning '-k option is ignored'
        ;;
      l)
        print_deprecation_warning '-l option is ignored'
        ;;
      s)
        SKIP_CENTOS_RELEASE_CHECK="true"
        SKIP_FREE_SPACE_CHECK="true"
        ;;
      *)
        common_parse_options "${option}" "${option_value}"
        ;;
    esac
  done
  ensure_options_correct
}

help_en(){
  echo "${SCRIPT_NAME} installs and configures Keitaro"
  echo
  echo "Example: ${SCRIPT_NAME}"
  echo
  echo "Modes:"
  echo "  -U                       upgrade the system configuration and tracker"
  echo
  echo "  -C                       rescue the system configuration and tracker"
  echo
  echo "Customization:"
  echo "  -a PATH_TO_PACKAGE       set path to Keitaro installation package"
  echo
  echo "  -t TAGS                  set ansible-playbook tags, TAGS=tag1[,tag2...]"
  echo
  echo "  -i TAGS                  set ansible-playbook ignore tags, TAGS=tag1[,tag2...]"
  echo
  echo "  -o output                sset the full path of the installer log output"
  echo
  echo "  -w                       do not run 'yum upgrade'"
  echo
}
MYIP_KEITARO_IO="https://myip.keitaro.io"

detect_server_ip() {
  debug "Detecting server IP address"
  debug "Getting url '${MYIP_KEITARO_IO}'"
  SERVER_IP="$(curl -fsSL4 ${MYIP_KEITARO_IO} 2>&1)"
  debug "Done, result is '${SERVER_IP}'"
}


stage1() {
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  detect_server_ip
  debug "Running in mode '${RUNNING_MODE}'"
}

assert_pannels_not_installed(){
  if is_installed mysql; then
    assert_isp_manager_not_installed
    assert_vesta_cp_not_installed
  fi
}


assert_isp_manager_not_installed(){
  if database_exists roundcube; then
    debug "ISP Manager database detected"
    fail "$(translate errors.isp_manager_installed)"
  fi
}


assert_vesta_cp_not_installed(){
  if database_exists admin_default; then
    debug "Vesta CP database detected"
    fail "$(translate errors.vesta_cp_installed)"
  fi
}


database_exists(){
  local database="${1}"
  debug "Check if database ${database} exists"
  mysql -Nse 'show databases' 2>/dev/null | tr '\n' ' ' | grep -Pq "${database}"
}

assert_server_ip_is_valid() {
  if ! valid_ip "${SERVER_IP}"; then
    fail "$(translate 'errors.cant_detect_server_ip')"
  fi
}

valid_ip(){
  local value="${1}"
  [[ "$value" =~  ^[[:digit:]]+(\.[[:digit:]]+){3}$ ]] && valid_ip_segments "$value"
}


valid_ip_segments(){
  local ip="${1}"
  local segments
  IFS='.' read -r -a segments <<< "${ip}"
  for segment in "${segments[@]}"; do
    if ! valid_ip_segment "${segment}"; then
      return "${FAILURE_RESULT}"
    fi
  done
}

valid_ip_segment(){
  local ip_segment="${1}"
  [ "$ip_segment" -ge 0 ] && [ "$ip_segment" -le 255 ]
}

assert_systemctl_works_properly () {
  local message
  message=$(print_with_color 'Checking if systemd works' 'blue')
  echo -en "${message} . "
  if systemctl &> /dev/null; then
    print_with_color 'OK' 'green'
  else
    print_with_color 'NOK' 'red'
    fail "$(translate errors.systemctl_doesnt_work_properly)"
  fi
}
MIN_RAM_SIZE_MB=1500

assert_has_enough_ram(){
  debug "Checking RAM size"

  local current_ram_size_mb
  current_ram_size_mb=$(get_ram_size_mb)
  if [[ "$current_ram_size_mb" -lt "$MIN_RAM_SIZE_MB" ]]; then
    debug "RAM size ${current_ram_size_mb}mb is less than ${MIN_RAM_SIZE_MB}mb, raising error"
    fail "$(translate errors.not_enough_ram)"
  else
    debug "RAM size ${current_ram_size_mb}mb is greater than ${MIN_RAM_SIZE_MB}mb, continuing"
  fi
}

assert_apache_not_installed(){
  if is_installed httpd; then
    fail "$(translate errors.apache_installed)"
  fi
}
MIN_FREE_DISK_SPACE_MB=2048

assert_has_enough_free_disk_space(){
  debug "Checking free disk spice"

  if [[ "${SKIP_FREE_SPACE_CHECK}" != "" ]] || is_running_in_rescue_mode; then
    debug "Free disk space checking skipped"
    return
  fi

  local current_free_disk_space_mb
  current_free_disk_space_mb=$(get_free_disk_space_mb)
  if [[ "${current_free_disk_space_mb}" -lt "${MIN_FREE_DISK_SPACE_MB}" ]]; then
    debug "Free disk space ${current_free_disk_space_mb}mb is less than ${MIN_FREE_DISK_SPACE_MB}mb, raising error"
    fail "$(translate errors.not_enough_free_disk_space)"
  else
    debug "Free disk space ${current_free_disk_space_mb}mb is greater than ${MIN_FREE_DISK_SPACE_MB}mb, continuing"
  fi
}


assert_thp_deactivatable() {
  debug "Checking if it is possible to disable THP"
  if is_ci_mode; then
    debug "Skip actual checking"
    return
  fi
  if are_thp_sys_files_existing; then
    debug "There are THP files in /sys fs, checking for ability to disable THP" 
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
    if [ "$thp_enabled" == "always madvise [never]" ]; then
      debug "OK, THP was successfully disabled"
    else
      fail "Can't disable Transparent Huge Pages" 
    fi
  else
    debug "There are no THP files in /sys fs, continuing installation process" 
  fi
}

are_thp_sys_files_existing() {
  file_exists "/sys/kernel/mm/transparent_hugepage/enabled" && file_exists "/sys/kernel/mm/transparent_hugepage/defrag"
}


assert_not_running_under_openvz() {
  debug "Assert we are not running under OpenVZ"

  virtualization_type="$(hostnamectl status | grep Virtualization | awk '{print $2}')"
  debug "Detected virtualization type: '${virtualization_type}'"
  if isset "${virtualization_type}" && [[ "${virtualization_type}" == "openvz" ]]; then
    fail "Servers with OpenVZ virtualization are not supported"
  fi
}

assert_running_on_supported_centos(){
  assert_installed 'yum' 'errors.wrong_distro'
  if ! file_exists /etc/centos-release; then
    fail "$(translate errors.wrong_distro)"
  fi
  if empty "${SKIP_CENTOS_RELEASE_CHECK}"; then
    if ! is_running_in_upgrade_mode; then
      assert_centos_release_is_supportded
    fi
  fi
}

assert_centos_release_is_supportded(){
  if ! file_content_matches /etc/centos-release '-P' '^CentOS .* (8|9)\b'; then
    fail "$(translate errors.wrong_distro)"
  fi
}

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_no_another_process_running
  assert_caller_root
  assert_apache_not_installed
  assert_running_on_supported_centos
  assert_systemctl_works_properly
  assert_has_enough_ram
  assert_has_enough_free_disk_space
  assert_not_running_under_openvz
  assert_pannels_not_installed
  assert_thp_deactivatable
  assert_server_ip_is_valid
  assert_architecture_is_valid
}

read_inventory(){
  detect_inventory_path
  if isset "${DETECTED_INVENTORY_PATH}"; then
    parse_inventory "${DETECTED_INVENTORY_PATH}"
  fi
}

parse_inventory() {
  local file="${1}"
  debug "Found inventory file ${file}, reading defaults from it"
  while IFS="" read -r line; do
    if [[ "$line" =~ = ]]; then
      parse_line_from_inventory_file "$line"
    fi
  done < "${file}"
}

parse_line_from_inventory_file(){
  local line="${1}"
  local quoted_string_regex="^'.*'\$"
  IFS="=" read -r var_name value <<< "$line"
  if [[ "$var_name" != "db_restore_path" ]]; then
    if [[ "${value}" =~ ${quoted_string_regex} ]]; then
      value_without_quotes="${value:1:-1}"
      value="${value_without_quotes}"
    fi
    if empty "${VARS[$var_name]}"; then
      VARS[$var_name]=$value
      debug "# read '$var_name' from inventory"
    else
      debug "# $var_name is set from options, skip inventory value"
    fi
    if [[ "${var_name}" =~ passw ]]; then
      debug "  $var_name=***MASKED***"
    else
      debug "  $var_name=${VARS[$var_name]}"
    fi
  fi
}

setup_vars() {
  detect_installed_version
  setup_default_value installer_version "${INSTALLED_VERSION}" "${RELEASE_VERSION}"
  setup_default_value db_name 'keitaro'
  setup_default_value ch_password "$(generate_password)"
  setup_default_value db_engine "${DB_ENGINE_DEFAULT}"
  if ! file_exists "${INVENTORY_DIR}/tracker.env"; then
    setup_default_value db_password "$(get_tracker_config_value 'db' 'password')" "$(generate_password)"
    setup_default_value db_root_password "$(get_config_value password "/root/.my.cnf" '=')" "$(generate_password)"
    setup_default_value db_user "$(get_tracker_config_value 'db' 'user')" 'keitaro'
    setup_default_value postback_key "$(get_config_value 'postback_key' "${TRACKER_CONFIG_FILE}" '=')"
    setup_default_value salt "$(get_config_value 'salt' "${TRACKER_CONFIG_FILE}" '=')" "$(generate_uuid)"
    setup_default_value table_prefix "$(get_tracker_config_value 'db' 'prefix')" 'keitaro_'
  fi
}

setup_default_value() {
  local var_name="${1}"
  local default_value="${2:-${3}}"
  if empty "${VARS[${var_name}]}"; then
    if [[ "${var_name}" =~ passw ]]; then
      debug "VARS['${var_name}'] is empty, set to '***MASKED***'"
    else
      debug "VARS['${var_name}'] is empty, set to '${default_value}'"
    fi
    VARS["${var_name}"]="${default_value}"
  else
    if [[ "${var_name}" =~ passw ]]; then
      debug "VARS['${var_name}'] is set to '***MASKED***'"
    else
      debug "VARS['${var_name}'] is set to '${VARS[$var_name]}'"
    fi
  fi
}

stage3(){
  debug "Starting stage 3: read values from inventory file"
  read_inventory
  setup_vars
  if is_running_in_upgrade_mode; then
    assert_upgrade_allowed
  else
    assert_keitaro_not_installed
  fi
}

get_ssh_port(){
  local ssh_port
  ssh_port=$(echo "${SSH_CLIENT}" | cut -d' ' -f 3)
  if empty "${ssh_port}"; then
    ssh_port="22"
  fi
  debug "Detected ssh port: ${ssh_port}"
  echo "${ssh_port}"
}

write_inventory_file(){
  debug 'Writing inventory file: STARTED'
  create_inventory_file
  print_line_to_inventory_file '[server]'
  print_line_to_inventory_file 'localhost'
  print_line_to_inventory_file
  print_line_to_inventory_file '[server:vars]'
  print_line_to_inventory_file "server_ip=${SERVER_IP}"
  print_line_to_inventory_file "cpu_cores=$(get_cpu_cores)"
  print_line_to_inventory_file "ssh_port=$(get_ssh_port)"
  print_line_to_inventory_file "sshd_port=$(detect_sshd_port)"
  print_line_to_inventory_file "db_engine=${VARS['db_engine']}"

  print_nonempty_inventory_item 'license_key' "'"
  print_nonempty_inventory_item 'postback_key'
  print_nonempty_inventory_item 'salt'
  print_nonempty_inventory_item 'table_prefix'
  print_nonempty_inventory_item 'ch_password'
  print_nonempty_inventory_item 'db_name'
  print_nonempty_inventory_item 'db_user'
  print_nonempty_inventory_item 'db_password'
  print_nonempty_inventory_item 'db_root_password'
  print_nonempty_inventory_item 'db_restore_path'
  print_nonempty_inventory_item 'installed'
  print_nonempty_inventory_item 'installer_version'

  if is_running_in_install_mode; then
    print_line_to_inventory_file "olap_db=${OLAP_DB_CLICKHOUSE}"
  else
    handle_changeable_inventory_item 'olap_db' "${KCTL_OLAP_DB}" "${OLAP_DB_DEFAULT}"
  fi
  handle_changeable_inventory_item 'ram_size_mb' "$(get_ram_size_mb)" "$(get_ram_size_mb)"


  debug "Writing inventory file: DONE"
}

print_nonempty_inventory_item() {
  local key="${1}"
  local quote="${2}"
  local value="${VARS[$key]}"
  if isset "${value}"; then
    print_key_value_to_inventory_file "${key}" "${quote}${value}${quote}"
  fi
}

handle_changeable_inventory_item() {
  local key="${1}"
  local key_changed="${key}_changed"
  local new_value="${2}"
  local default_value="${3}"
  local current_value="${VARS["${key}"]}"

  if is_inventory_value_changed "${key_changed}" "${new_value}" "${current_value}"; then
    VARS["${key}"]="${new_value:-${default_value}}"
    VARS["${key_changed}"]="true"
    print_line_to_inventory_file "${key}=${VARS[${key}]}"
    print_line_to_inventory_file "${key_changed}=true"
  else
    print_line_to_inventory_file "${key}=${current_value:-${default_value}}"
  fi
}

is_inventory_value_changed() {
  local key_changed="${1}"
  local new_value="${2}"
  local current_value="${3}"

  ( isset "${VARS[${key_changed}]}" ) || \
    ( isset "${new_value}" && [[ "${new_value}" != "${current_value}" ]] )
}

create_inventory_file() {
  mkdir -p "${INVENTORY_DIR}" || fail "Cant't create keitaro inventory dir ${INVENTORY_DIR}"
  chmod 0750 "${INVENTORY_DIR}" || fail "Cant't set permissions keitaro inventory dir ${INVENTORY_DIR}"
  (echo -n > "${INVENTORY_PATH}" && chmod 0600 "${INVENTORY_PATH}") || \
    fail "Cant't create keitaro inventory file ${INVENTORY_PATH}"
}

get_cpu_cores() {
  cpu_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
  if [[ "$cpu_cores" == "0" ]]; then
    cpu_cores=1
  fi
  echo "$cpu_cores"
}

print_key_value_to_inventory_file() {
  local key="${1}" value="${2}"
  if [[ "${key}" =~ /passw/ ]]; then
    print_line_to_inventory_file "${key}=${value}" "${key}=***MASKED***"
  else
    print_line_to_inventory_file "${key}=${value}"
  fi
}

print_line_to_inventory_file() {
  local line="${1}" message="${2:${1}}"
  debug "  '${message}'"
  echo "$line" >> "$INVENTORY_PATH"
}

DEFAULT_SSH_PORT="22"

detect_sshd_port() {
  local port
  if ! is_ci_mode && is_installed ss; then
    debug "Detecting sshd port"
    port=$(ss -l -4 -p -n | grep -w tcp | grep -w sshd | awk '{ print $5 }' | awk -F: '{ print $2 }' | head -n1)
    debug "Detected sshd port: ${port}"
  fi
  if empty "${port}"; then
    debug "Reset detected sshd port to 22"
    port="${DEFAULT_SSH_PORT}"
  fi
  echo "${port}"
}

stage4() {
  debug "Starting stage 4: generate inventory file (running mode is ${RUNNING_MODE})."
  upgrades.run_upgrade_checkpoints 'early'
  write_inventory_file
}

install_ansible() {
  install_package 'epel-release'
  install_package "$(get_ansible_package_name)"
  install_ansible_collection "community.mysql"
  install_ansible_collection "containers.podman"
  install_ansible_collection "community.general"
  install_ansible_collection "ansible.posix"
}


install_core_packages() {
  if install_core_packages.is_centos8_distro; then
    install_core_packages.switch_to_centos8_stream
  fi

  if [[ "$(get_centos_major_release)" == "8" ]] && is_running_in_install_mode; then
    upgrade_package 'rpm'
  fi

  install_packages epel-release file tar curl crontabs logrotate jq unzip
  install_core_packages.install_podman
}

install_core_packages.install_podman() {
  if is_package_installed 'podman-docker'; then
    return
  fi

  install_package 'podman-docker'

  if [[ "$(get_centos_major_release)" == "8" ]]; then
    install_package 'libseccomp-devel'
  fi

  if [[ "$(get_centos_major_release)" != "7" ]]; then
    install_core_packages.install_podman.start_and_enable_podman_unit
  fi
}

install_core_packages.install_podman.start_and_enable_podman_unit() {
  if ! systemctl is-active 'podman' &>/dev/null; then
    systemd.enable_service 'podman'
    systemd.restart_service 'podman'
  fi
}

install_core_packages.is_centos8_distro() {
  file_content_matches /etc/centos-release '-P' '^CentOS Linux.* 8\b'
}

install_core_packages.switch_to_centos8_stream() {
  local repo_base_url="http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages"
  local release="8-6"
  local gpg_keys_package_url="${repo_base_url}/centos-gpg-keys-${release}.el8.noarch.rpm"
  local repos_package_url="${repo_base_url}/centos-stream-repos-${release}.el8.noarch.rpm"
  debug 'Switching CentOS 8 -> CentOS Stream 8'
  print_with_color 'Switching CentOS 8 -> CentOS Stream 8:' 'blue'
  run_command "dnf install -y --nobest --allowerasing ${gpg_keys_package_url} ${repos_package_url}" \
              "  Installing CentOS Stream repos"
  # run_command "dnf swap centos-{linux,stream}-repos -y" "  Switching to CentOS Stream"
  run_command "dnf distro-sync -y" "  Syncing distro"
}

install_kctl() {
  install_kctl.install_components_env
  install_kctl.preinstall_kctl
  install_kctl.install_kctl_files
  install_kctl.install_components
  install_kctl.configure_systemd
}

disable_selinux() {
  if [[ "$(get_selinux_status)" == "Enforcing" ]]; then
    run_command 'setenforce 0' 'Disabling Selinux' 'hide_output'
  fi

  if file_exists /usr/sbin/setroubleshootd; then
    run_command 'yum erase setroubleshoot-server -y && systemctl daemon-reload' 'Removing setroubleshootd' 'hide_output'
  fi
}

get_selinux_status(){
  getenforce
}

install_kctl.install_components() {
  if is_running_in_install_mode; then
    components.install "nginx-starting-page"
    systemd.update_units
    systemd.disable_and_stop_service "nginx"
    systemd.enable_and_start_service "nginx-starting-page"
  fi

  for component in certbot certbot-renew clickhouse mariadb nginx redis; do
    local current_image; current_image="$(components.get_var "${component}" 'image')";
    local applied_image; applied_image="$(components.get_applied_var "${component}" 'image')";

    if [[ "${current_image}" != "${applied_image}" ]]; then
      components.install "${component}"
    fi
  done

  for component in kctl-ch-converter kctld roadrunner; do
    local current_url; current_url="$(components.get_var "${component}" 'url')";
    local applied_url; applied_url="$(components.get_applied_var "${component}" 'url')";

    if [[ "${current_url}" != "${applied_url}" ]]; then
      components.install_binaries "${component}"
    fi
  done

  components.preinstall 'tracker'
}

install_kctl.install_kctl_files() {
  local provivsion_directory msg

  preinstalled_kctl_directory="$(components.get_directory "${KCTL_COMPONENT}")"
  msg="Installing kctl from ${preinstalled_kctl_directory}"
  debug "${msg}"; print_with_color "${msg}" "blue"
  install_kctl.install_kctl_files.install_binaries "${preinstalled_kctl_directory}"
  install_kctl.install_kctl_files.install_configs "${preinstalled_kctl_directory}"
}

install_kctl.install_kctl_files.install_binaries() {
  local preinstalled_kctl_directory="${1}"

  install "${preinstalled_kctl_directory}"/bin/* "${KCTL_BIN_DIR}"/

  for existing_file_path in "${KCTL_BIN_DIR}"/*; do
    local file_name="${existing_file_path##*/}"
    ln -s -f "${existing_file_path}" "/usr/local/bin/${file_name}"
  done

  install -m 0755 "${preinstalled_kctl_directory}/files/bin/"* "${ROOT_PREFIX}/usr/local/bin/"
}

install_kctl.install_kctl_files.install_configs() {
  local preinstalled_kctl_directory="${1}"

  mkdir -p "${ROOT_PREFIX}/etc/keitaro/env/components/"
  mkdir -p "${ROOT_PREFIX}/etc/keitaro/config/"
  mkdir -p "${ROOT_PREFIX}/etc/nginx/"
  mkdir -p "${ROOT_PREFIX}/etc/containers/registries.conf.d/"

  install -m 0444 "${preinstalled_kctl_directory}/files/etc/sudoers.d"/* "${ROOT_PREFIX}/etc/sudoers.d/"
  install -m 0755 "${preinstalled_kctl_directory}/files/etc/cron.daily"/* "${ROOT_PREFIX}/etc/cron.daily/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/cron.d"/keitaro-traffic-log-trimmer "${ROOT_PREFIX}/etc/cron.d/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/systemd/system"/* "${ROOT_PREFIX}/etc/systemd/system/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/keitaro/env/components"/* "${ROOT_PREFIX}/etc/keitaro/env/components/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/keitaro/config"/*.env "${ROOT_PREFIX}/etc/keitaro/config/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/logrotate.d"/* "${ROOT_PREFIX}/etc/logrotate.d"/
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/nginx"/* "${ROOT_PREFIX}/etc/nginx/"
  install -m 0644 "${preinstalled_kctl_directory}/files/etc/containers"/nodocker "${ROOT_PREFIX}/etc/containers/"

  if [[ "$(get_centos_major_release)" != "7" ]]; then
    install -m 0644 "${preinstalled_kctl_directory}/files/etc/containers/registries.conf.d"/* \
            "${ROOT_PREFIX}/etc/containers/registries.conf.d/"
  fi
}

install_kctl.preinstall_kctl() {
  local path_to_preinstalled_kctl msg installer_mode

  components.preinstall 'kctl'

  if [[ "${KCTL_IN_KCTL}" != "" ]]; then
    return
  fi

  if is_running_in_install_mode; then
    return
  fi

  if is_ci_mode; then
    return
  fi

  if install_kctl.need_to_run_new_kctl; then
    path_to_preinstalled_kctl="$(components.get_directory 'kctl')"

    msg="Running new KCTL from ${path_to_preinstalled_kctl}"
    debug "${msg}"; print_with_color "  ${msg}" 'blue'

    if is_running_in_rescue_mode; then
      installer_mode="C"
    else
      installer_mode="U"
    fi

    msg="Running \`KCTL_IN_KCTL=true SKIP_CACHE='' ${path_to_preinstalled_kctl}/bin/kctl-install -${installer_mode}\`"
    debug "${msg}"; print_with_color "  ${msg}" 'blue'
    KCTL_IN_KCTL=true SKIP_CACHE='' "${path_to_preinstalled_kctl}/bin/kctl-install" -${installer_mode}

    exit
  fi
}

install_kctl.need_to_run_new_kctl() {
  local kctl_url applied_kctl_url

  if [[ -f "${PATH_TO_APPLIED_COMPONENTS_ENV}" ]]; then
    kctl_url="$(components.get_var 'kctl' 'url')"
    applied_kctl_url="$(components.get_applied_var 'kctl' 'url')"

    [[ "${kctl_url}" != "${applied_kctl_url}" ]]
  fi
}

install_kctl.configure_systemd() {
  systemd.update_units
  systemd.enable_service 'schedule-fs-check-on-boot'
  systemd.restart_service 'schedule-fs-check-on-boot'
  systemd.enable_service 'disable-thp'
  systemd.restart_service 'disable-thp'
  systemd.enable_service 'kctl-monitor'
  systemd.restart_service 'kctl-monitor'
  systemd.enable_service 'kctld-worker'
  systemd.enable_service 'kctld-server'
  if [[ "${KCTLD_MODE}" == "true" ]]; then
    systemd.start_service 'kctld-worker'
    systemd.start_service 'kctld-server'
  else
    systemd.restart_service 'kctld-worker'
    systemd.restart_service 'kctld-server'
  fi
}


install_kctl.install_components_env() {
  local components_env_url

  if [[ "${COMPONENTS_ENV_URL:-}" != "" ]]; then
    components_env_url="${COMPONENTS_ENV_URL}"
  elif [[ "${KEITARO_VERSION:-}" != "" ]]; then
    components_env_url="${FILES_KEITARO_ROOT_URL}/keitaro/keitaro/releases/${KEITARO_VERSION}/components.env"
  else
    components_env_url="$(SKIP_CACHE=true install_kctl.install_components_env.get_components_env_url)"
  fi

  SKIP_CACHE=true install_kctl.install_components_env.install "${components_env_url}"
}

install_kctl.install_components_env.get_components_env_url() {
  local local_keitaro_version remote_keitaro_version update_channel

  local_keitaro_version="$(install_kctl.install_components_env.get_local_keitaro_version)"

  update_channel="$(install_kctl.install_components_env.get_update_channel)"

  remote_keitaro_version="$(release_api.get_keitaro_version "${local_keitaro_version}" "${update_channel}")"
  debug "Got remote keitaro version: ${remote_keitaro_version}"

  echo "${FILES_KEITARO_ROOT_URL}/keitaro/keitaro/releases/${remote_keitaro_version}/components.env"
}

install_kctl.install_components_env.get_local_keitaro_version() {
  local local_keitaro_version

  if is_running_in_install_mode; then
    debug "Running in install mode - do not pass Keitaro version"
    return
  fi

  local_keitaro_version="$(components.get_keitaro_version)"
  debug "Got local keitaro version from components: ${local_keitaro_version}"

  if [[ "${local_keitaro_version}" == "" ]]; then
    local_keitaro_version="$(tracker.get_version)"
    debug "Got local keitaro version from installed tracker: ${local_keitaro_version}"
  fi

  echo "${local_keitaro_version}"
}

install_kctl.install_components_env.get_update_channel() {
  local update_channel

  if [[ "${UPDATE_CHANNEL:-}" != "" ]]; then
    debug "Got update channel from env UPDATE_CHANNEL ${UPDATE_CHANNEL}"
    echo "${UPDATE_CHANNEL}"
    return
  fi

  if is_running_in_install_mode; then
    debug "Running in install mode, set update channel to default ${DEFAULT_UPDATE_CHANNEL}"
    echo "${DEFAULT_UPDATE_CHANNEL}"
    return
  fi

  update_channel="$(env_files.get_var "${PATH_TO_SYSTEM_ENV}" "UPDATE_CHANNEL")"
  if [[ "${update_channel}" != "" ]]; then
    debug "Got update channel from ${PATH_TO_SYSTEM_ENV} - ${update_channel}"
    echo "${update_channel}"
    return
  fi

  if versions.lt "${local_keitaro_version}" "10.0.0"; then
    debug "Too old tracker v${local_keitaro_version} is installed set update channel to ${DEFAULT_UPDATE_CHANNEL}"
    echo "${DEFAULT_UPDATE_CHANNEL}"
    return
  fi

  update_channel="$(tracker.get_update_channel)"

  if [[ "${update_channel}" != "" ]]; then
    debug "Got update channel from tracker - ${update_channel}"
    echo "${update_channel}"
    return
  fi

  debug "Using default update channel - ${DEFAULT_UPDATE_CHANNEL}"
  echo "${DEFAULT_UPDATE_CHANNEL}"
}

install_kctl.install_components_env.install() {
  local components_env_url="${1}"

  cache.retrieve_or_download "${components_env_url}"

  path_to_new_components_env="$(cache.path_by_url "${components_env_url}")"

  mkdir -p "${PATH_TO_ENV_DIR}"
  install -m 0600 "${path_to_new_components_env}" "${PATH_TO_ENV_DIR}"
}

FASTESTMIROR_CONF_PATH="/etc/yum/pluginconf.d/fastestmirror.conf"

disable_fastestmirror(){
  local disabling_message="Disabling mirrors in repo files"
  local disabling_command="sed -i -e 's/^#baseurl/baseurl/g; s/^mirrorlist/#mirrorlist/g;'  /etc/yum.repos.d/*"
  run_command "${disabling_command}" "${disabling_message}" "hide_output"

  if [[ "$(get_centos_major_release)" == "7" ]] && is_fastestmirror_enabled; then
    disabling_message="Disabling fastestmirror plugin on Centos7"
    disabling_command="sed -i -e 's/^enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf"
    run_command "${disabling_command}" "${disabling_message}" "hide_output"
  fi
}

is_fastestmirror_enabled() {
  file_exists "${FASTESTMIROR_CONF_PATH}" && \
      grep -q '^enabled=1' "${FASTESTMIROR_CONF_PATH}"
}
clean_packages_metadata() {
  if empty "$WITHOUTH_YUM_UPDATE"; then
    run_command "yum clean all" "Cleaninig yum meta" "hide_output"
  fi
}

stage5() {
  debug "Starting stage 5: upgrade current and install necessary packages"

  disable_fastestmirror
  disable_selinux
  clean_packages_metadata
  if is_running_in_rescue_mode; then
    cache.purge
  fi

  system.users.create "${KEITARO_SUPPORT_USER}" "${KEITARO_SUPPORT_HOME_DIR}"

  install_core_packages
  install_kctl
  install_ansible
}

stage6() {
  debug "Running stage6"
}

stage7.enable_services() {
  systemd.enable_service "clickhouse"
  systemd.enable_service "mariadb"
  systemd.enable_service "nginx"
  systemd.enable_service "redis"
}

json2dict() {
  # the largest part of the code is gotten from https://github.com/dominictarr/JSON.sh
  throw() {
    echo "$*" >&2
    exit 1
  }

  BRIEF=1               # Brief. Combines 'Leaf only' and 'Prune empty' options.
  LEAFONLY=0            # Leaf only. Only show leaf nodes, which stops data duplication.
  PRUNE=0               # Prune empty. Exclude fields with empty values.
  NO_HEAD=0             # No-head. Do not show nodes that have no path (lines that start with []).
  NORMALIZE_SOLIDUS=0   # Remove escaping of the solidus symbol (straight slash)

  tokenize() {
    local GREP='grep -ao -E --color=never'
    local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    local CHAR='[^[:cntrl:]"\\]'
    local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
    local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
    local KEYWORD='null|false|true'
    local SPACE='[[:space:]]+'

    $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | grep -v -E "^$SPACE$"
  }

  parse_array() {
    local index=0
    local ary=''
    read -r token
    printf "['%s']=\"" "${1}"
    case "$token" in
      ']') ;;
      *)
        while :
        do
          parse_value "$1" "[$index]"
          index=$((index+1))
          ary="$ary""$value"
          read -r token
          case "$token" in
            ']') break ;;
            ',') ary="$ary," ;;
            *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
        ;;
    esac
    printf '" '
    [[ "$BRIEF" -eq 0 ]] && value=$(printf '[%s]' "$ary") || value=
    :
  }

  parse_object() {
    local key
    local obj=''
    read -r token
    case "$token" in
      '}') ;;
      *)
        while :
        do
          case "$token" in
            '"'*'"') key=$token ;;
            *) throw "EXPECTED string GOT ${token:-EOF}" ;;
          esac
          read -r token
          case "$token" in
            ':') ;;
            *) throw "EXPECTED : GOT ${token:-EOF}" ;;
          esac
          read -r token
          local json_key=${key//\"}
          parse_value "$1" "$json_key" "."
          obj="$obj$key:$value"
          read -r token
          case "$token" in
            '}') break ;;
            ',') obj="$obj," ;;
            *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
          esac
          read -r token
        done
      ;;
    esac
    [[ "$BRIEF" -eq 0 ]] && value=$(printf '{%s}' "$obj") || value=
    :
  }

  parse_value() {
    local jpath="${1:+$1$3}$2" isleaf=0 isempty=0 print=0
    case "$token" in
      '{') parse_object "$jpath" ;;
      '[') parse_array  "$jpath" ;;
      # At this point, the only valid single-character tokens are digits.
      ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
      *) value=$token
        # if asked, replace solidus ("\/") in json strings with normalized value: "/"
        [[ "$NORMALIZE_SOLIDUS" -eq 1 ]] && value="${value//\\}"
        isleaf=1
        [[ "$value" = '""' ]] && isempty=1
        ;;
    esac

    [[ "$value" = '' ]] && return
    [[ "$NO_HEAD" -eq 1 ]] && [[ -z "$jpath" ]] && return

    [[ "$LEAFONLY" -eq 0 ]] && [[ "$PRUNE" -eq 0 ]] && print=1
    [[ "$LEAFONLY" -eq 1 ]] && [[ "$isleaf" -eq 1 ]] && [[ $PRUNE -eq 0 ]] && print=1
    [[ "$LEAFONLY" -eq 0 ]] && [[ "$PRUNE" -eq 1 ]] && [[ "$isempty" -eq 0 ]] && print=1
    [[ "$LEAFONLY" -eq 1 ]] && [[ "$isleaf" -eq 1 ]] && [[ $PRUNE -eq 1 ]] && [[ $isempty -eq 0 ]] && print=1

    [[ "$print" -eq 1 ]] && [[ "$value" != 'null' ]] && print_value "$jpath" "$value"
    :
  }

  print_value() {
    local jpath="$1" value="$2"
    if [[ "${jpath}" =~ \[ ]]; then
      printf "%s " "${value:1:-1}" # remove quotas
    else
      printf "['%s']=%s " "$jpath" "$value"
    fi
  }

  json_parse() {
    read -r token
    parse_value
    read -r token
    case "$token" in
      '') ;;
      *) throw "EXPECTED EOF GOT $token" ;;
    esac
  }

  printf "( %s)" "$(tokenize | json_parse || true)"
}

stage7.write_inventory_on_finish() {
  debug "Signaling successful installation by writing 'installed' flag to the inventory file"
  VARS['db_password']=""
  VARS['db_restore_path']=""
  VARS['db_root_password']=""
  VARS['installed']=true
  VARS['installer_version']="${RELEASE_VERSION}"
  VARS['license_key']=""
  VARS['salt']=""
  VARS['postback_key']=""
  reset_changeable_values
  write_inventory_file
}


reset_changeable_values() {
  for key in "${!VARS[@]}"; do
    if [[ "${key}" =~ _changed$ ]]; then
      debug "resetting key VARS[${key}]"
      VARS["${key}"]=""
    fi
  done
}


ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^(fatal|failed): \[localhost\]: [A-Z]+! => "
ANSIBLE_LAST_TASK_LOG="${WORKING_DIR}/ansible_last_task.log"

stage7.run_ansible_playbook() {
  local env cmd tracker_version_to_install tracker_directory playbook_directory

  tracker_version_to_install="$(components.get_var "${TRACKER_COMPONENT}" 'version')"
  tracker_directory="$(components.get_directory "${TRACKER_COMPONENT}")"
  playbook_directory="$(components.get_directory "${KCTL_COMPONENT}")/playbook"

  env="${env} ANSIBLE_FORCE_COLOR=true"
  env="${env} ANSIBLE_CONFIG=${playbook_directory}/ansible.cfg"
  env="${env} KCTL_RUNNING_MODE=${RUNNING_MODE}"
  env="${env} KCTL_TRACKER_DIRECTORY=${tracker_directory}"
  env="${env} KCTL_TRACKER_VERSION_TO_INSTALL=${tracker_version_to_install}"

  cmd="${env} $(get_ansible_playbook_command) -v -i ${INVENTORY_PATH} ${playbook_directory}/playbook.yml"

  expand_ansible_tags_on_upgrade
  if isset "${ANSIBLE_TAGS}"; then
    cmd="${cmd} --tags ${ANSIBLE_TAGS}"
  fi
  if isset "${ANSIBLE_IGNORE_TAGS}"; then
    cmd="${cmd} --skip-tags ${ANSIBLE_IGNORE_TAGS}"
  fi
  run_command "${cmd}" '' '' '' '' 'print_ansible_fail_message'
}

get_ansible_playbook_command() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "LC_ALL=C ansible-playbook-3"
  else
    echo "LC_ALL=C.UTF-8 ansible-playbook"
  fi
}

print_ansible_fail_message(){
  local current_command_script="${1}"
  if ansible_task_found; then
    debug "Found last ansible task"
    print_tail_content_of "$CURRENT_COMMAND_ERROR_LOG"
    cat "$CURRENT_COMMAND_OUTPUT_LOG" | remove_text_before_last_pattern_occurence "$ANSIBLE_TASK_HEADER" > "$ANSIBLE_LAST_TASK_LOG"
    print_ansible_last_task_info
    print_ansible_last_task_external_info
    rm "$ANSIBLE_LAST_TASK_LOG"
  else
    print_common_fail_message "$current_command_script"
  fi
}

ansible_task_found(){
  grep -qE "$ANSIBLE_TASK_HEADER" "$CURRENT_COMMAND_OUTPUT_LOG"
}

print_ansible_last_task_info(){
  echo "Task info:"
  head -n2 "$ANSIBLE_LAST_TASK_LOG" | sed -r 's/\*+$//g' | add_indentation
}

print_ansible_last_task_external_info(){
  if file_content_matches "${ANSIBLE_LAST_TASK_LOG}" "-P" "${ANSIBLE_TASK_FAILURE_HEADER}"; then
    debug "Found ansible failure"
    echo
    cat "${ANSIBLE_LAST_TASK_LOG}" | extract_ansible_task_json | print_ansible_task_json
  fi
}

extract_ansible_task_json() {
  # The json with error is inbuilt into text. The structure of the text is about:
  #
  # TASK [$ROLE_NAME : "$TASK_NAME"] *******
  # task path: /path/to/task/file.yml:$LINE
  # fatal: [localhost]: FAILED! => {"some": "json", "content": "here"}
  #
  # So, we simply remove JSON prefix (fatal: ... => ) from this message
  grep -Po "${ANSIBLE_TASK_FAILURE_HEADER}\K.*" | head -n 1
}

remove_text_before_last_pattern_occurence(){
  local pattern="${1}"
  sed -n -r "H;/${pattern}/h;\${g;p;}"
}

print_ansible_task_json() {
  local error_dict_string
  read -r json_string

  error_dict_string="$(echo "${json_string}" | json2dict)"

  declare -A error_dict="${error_dict_string}"

  if isset "${error_dict['cmd']}" || isset "${error_dict['msg']}" || isset "${error_dict['stdout']}" || isset "${error_dict['stderr']}"; then
     print_field_content "ansible module" "${error_dict['invocation.module_name']}"
     print_field_content "command" "${error_dict['cmd']}"
     print_field_content "error" "${error_dict['msg']}"
     print_field_content "stdout" "${error_dict['stdout']}"
     print_field_content "stderr" "${error_dict['stderr']}"
  else
    for field in "${!error_dict[@]}"; do
      if [[ ! "${field}" =~ _lines$ ]]; then
        print_field_content "${field}" "${error_dict["${field}"]}"
      fi
    done
  fi
}

print_field_content() {
  local field_caption="${1}" field_content="${2}"

  if isset "${field_content}"; then
    if [[ "${field_content}" =~ \\\n ]]; then
      echo "----------------------------------  ${field_caption^^} ----------------------------------"
      echo -e "${field_content}"
      echo "----------------------------------  ${field_caption^^} ----------------------------------"
    else
      echo "${field_caption^^}: ${field_content}" | add_indentation
    fi
    echo
  fi
}

stage7() {
  debug "Starting stage 7: run ansible playbook"
  upgrades.run_upgrade_checkpoints 'pre'
  stage7.run_ansible_playbook
  clean_up
  upgrades.run_upgrade_checkpoints 'post'
  stage7.enable_services
  components.save_applied
  stage7.write_inventory_on_finish
  systemd.restart_service kctl-monitor
}

print_successful_message(){
  print_with_color "$(translate "messages.successful_${RUNNING_MODE}")" 'green'
  print_with_color "$(translate 'messages.visit_url')" 'green'
  print_url
}

print_url() {
  print_with_color "http://${SERVER_IP}/admin" 'light.green'
}

upgrade_packages() {
  if empty "$WITHOUTH_YUM_UPDATE"; then
    debug "Upgrading packages"
    if [[ "$(get_centos_major_release)" == "7" ]]; then
      run_command "yum update -y"
    else
      run_command "yum update -y --nobest"
    fi
  fi
}

stage8() {
  debug "Starting stage 8: finalyze installation"
  upgrade_packages
  print_successful_message
}

earlyupgrade_checkpoint_2_42_1() {
  upgrades.run_upgrade_checkpoint_command "rm -f /etc/logrotate.d/{redis,mysql}" \
            "Removing old logrotate configs"

  if [[ "$(get_centos_major_release)" == "8" ]]; then
    upgrade_package 'rpm'
  fi
}

earlyupgrade_checkpoint_2_40_0() {
  earlyupgrade_checkpoint_2_40_0.move_nginx_file \
          /etc/nginx/conf.d/vhosts.conf /etc/nginx/conf.d/keitaro.conf

  for old_dir in /etc/ssl/certs /etc/nginx/ssl; do
    for cert_name in dhparam.pem cert.pem privkey.pem; do
      earlyupgrade_checkpoint_2_40_0.move_nginx_file \
              "${old_dir}/${cert_name}" "/etc/keitaro/ssl/${cert_name}"
    done
  done

  earlyupgrade_checkpoint_2_40_0.remove_old_log_format_from_nginx_configs

  earlyupgrade_checkpoint_2_40_0.disable_and_stop_services
}

earlyupgrade_checkpoint_2_40_0.move_nginx_file() {
  local path_to_old_file="${1}" path_to_new_file="${2}" old_configs_count cmd msg

  if [[ -f "${path_to_old_file}" ]] && [[ ! -f ${path_to_new_file} ]]; then
    cmd="mkdir -p '${path_to_new_file%/*}'"
    cmd="${cmd} && mv '${path_to_old_file}' '${path_to_new_file}'"

    upgrades.run_upgrade_checkpoint_command "${cmd}" "Moving ${path_to_old_file} -> ${path_to_new_file}"
  fi

  old_configs_count="$(grep -r -l -F "${path_to_old_file}" /etc/nginx | wc -l)"

  if [[ "${old_configs_count}" != "0" ]]; then
    cmd="grep -r -l -F '${path_to_old_file}' /etc/nginx"
    cmd="${cmd} | xargs -r sed -i 's|${path_to_old_file}|${path_to_new_file}|g'"

    upgrades.run_upgrade_checkpoint_command "${cmd}" \
            "Changing path ${path_to_old_file} -> ${path_to_new_file} in ${old_configs_count} nginx configs"
  fi
}


earlyupgrade_checkpoint_2_40_0.remove_old_log_format_from_nginx_configs() {
  local old_log_format="tracker.status" cmd

  old_configs_count="$(grep -r -l -F "${old_log_format}" /etc/nginx/conf.d | wc -l)"

  if [[ "${old_configs_count}" != "0" ]]; then
    cmd="grep -r -l -F '${old_log_format}' /etc/nginx/conf.d | xargs -r sed -i '/${old_log_format}/d'"

    upgrades.run_upgrade_checkpoint_command "${cmd}" \
            "Removing old log format ${old_log_format} from ${old_configs_count} nginx configs"
  fi
}

earlyupgrade_checkpoint_2_40_0.disable_and_stop_services() {
  if systemctl list-unit-files | grep -q redis.service; then
    systemd.disable_and_stop_service 'redis'
  fi
  if systemctl list-unit-files | grep -q mariadb.service; then
    systemd.disable_and_stop_service 'mariadb'
  fi
  if systemctl list-unit-files | grep -q nginx.service; then
    systemd.disable_and_stop_service 'nginx'
  fi
  if systemctl list-unit-files | grep -q clickhouse.service; then
    systemd.disable_and_stop_service 'clickhouse'
  fi
}

earlyupgrade_checkpoint_2_41_10() {
  earlyupgrade_checkpoint_2_41_10.remove_packages
  earlyupgrade_checkpoint_2_41_10.change_nginx_home
  earlyupgrade_checkpoint_2_41_10.remove_repos
  earlyupgrade_checkpoint_2_41_10.remove_old_ansible
}


PACKAGES_TO_REMOVE_SINCE_2_41_10=(
  nginx redis clickhouse-server MariaDB-server MariaDB-client MariaDB-tokudb-engine MariaDB-common MariaDB-shared
)


earlyupgrade_checkpoint_2_41_10.remove_packages() {
  for package in "${PACKAGES_TO_REMOVE_SINCE_2_41_10[@]}"; do
    if is_package_installed "${package}"; then
      upgrades.run_upgrade_checkpoint_command "yum erase -y ${package}" "Erasing ${package} package"
    fi
  done
}

earlyupgrade_checkpoint_2_41_10.change_nginx_home() {
  local nginx_home
  nginx_home="$( (getent passwd nginx | awk -F: '{print $6}') &>/dev/null || true)"
  if [[ "${nginx_home}" != "/var/cache/nginx" ]]; then
    upgrades.run_upgrade_checkpoint_command "usermod -d /var/cache/nginx nginx; rm -rf /home/nginx" "Changing nginx user home"
  fi
}

earlyupgrade_checkpoint_2_41_10.remove_repos() {
  if [ -f /etc/yum.repos.d/mariadb.repo ]; then
    upgrades.run_upgrade_checkpoint_command "rm -f /etc/yum.repos.d/mariadb.repo" "Removing mariadb repo"
  fi
  if [ -f /etc/yum.repos.d/Altinity-ClickHouse.repo ]; then
    upgrades.run_upgrade_checkpoint_command "rm -f /etc/yum.repos.d/Altinity-ClickHouse.repo" "Removing clickhouse repo"
  fi
}

earlyupgrade_checkpoint_2_41_10.remove_old_ansible() {
  if [[ "$(get_centos_major_release)" == "7" ]] && [[ -f /usr/bin/ansible-2 ]]; then
    upgrades.run_upgrade_checkpoint_command "yum erase -y ansible" "Removing old ansible"
  fi
  if [[ "$(get_centos_major_release)" == "8" ]] && is_package_installed "ansible"; then
    upgrades.run_upgrade_checkpoint_command "yum install -y ansible-core --allowerasing" "Removing old ansible"
  fi
}

postupgrade_checkpoint_2_41_7() {
  if ! components.wait_until_is_up 'mariadb'; then
    fail "Couldn't connect to mariadb"
  fi
  if ! components.wait_until_is_up 'clickhouse'; then
    fail "Couldn't connect to clickhouse"
  fi
  postupgrade_checkpoint_2_41_7.fix_ch_ttl
}

postupgrade_checkpoint_2_41_7.fix_ch_ttl() {
  local olap_db db_ttl ch_ttl

  olap_db="$(get_olap_db)"
  debug "Current OLAP_DB is ${olap_db}"

  if [[ "${olap_db}" == "${OLAP_DB_CLICKHOUSE}" ]]; then
    upgrades.print_checkpoint_info "Current OLAP DB is ${olap_db}, changing TTL in CH tables"
    db_ttl="$(postupgrade_checkpoint_2_41_7.get_db_ttl)"
    if [[ "${db_ttl}" == "" ]] || [[ ! "${db_ttl}" =~ ^[0-9]+$ ]]; then
      fail "Could not detect correct MariaDB ttl. Detected value is '${db_ttl}'"
    fi
    ch_ttl="$(postupgrade_checkpoint_2_41_7.get_ch_ttl)"
    if [[ "${ch_ttl}" == "" ]] || [[ ! "${ch_ttl}" =~ ^[0-9]+$ ]]; then
      fail "Could not detect correct MariaDB ttl. Detected value is '${ch_ttl}'"
    fi
    if [[ "${db_ttl}" != "${ch_ttl}" ]]; then
      postupgrade_checkpoint_2_41_7.set_ch_table_ttl "keitaro_clicks" "datetime" "${db_ttl}"
      postupgrade_checkpoint_2_41_7.set_ch_table_ttl "keitaro_conversions" "postback_datetime" "${db_ttl}"
    else
      upgrades.print_checkpoint_info "Skip changing CH TTL - it is already set to ${ch_ttl}"
    fi
  else
    upgrades.print_checkpoint_info "Current OLAP DB is ${olap_db}, skip changing TTL in CH"
  fi

  if [[ -f /sbin/manage-thp ]]; then
    upgrades.run_upgrade_checkpoint_command 'rm -f /sbin/manage-thp' 'Removing manage-thp'
  fi
}

postupgrade_checkpoint_2_41_7.get_ch_ttl() {
  local table_sql ch_tt show_table_query='show create table keitaro_clicks'

  table_sql="$("${KCTL_BIN_DIR}"/kctl run clickhouse-query "${show_table_query}")"

  if [[ "${table_sql}" != "" ]]; then
    ch_ttl="$(echo -e "${table_sql}" | grep -oP '(?<=TTL datetime \+ toIntervalDay\()[0-9]+')"
    if [[ "${ch_ttl}" == "" ]]; then
      ch_ttl="0"
    fi
    echo "${ch_ttl}"
  fi
}

postupgrade_checkpoint_2_41_7.get_db_ttl() {
  "${KCTL_BIN_DIR}"/kctl run cli-php system:get_setting 'stats_ttl'
}

postupgrade_checkpoint_2_41_7.set_ch_table_ttl() {
  local table="${1}" datetime_field="${2}" ttl="${3}" sql msg

  if [[ "${ttl}" == "0" ]]; then
    sql="ALTER TABLE ${table} REMOVE TTL"
    msg="Removing TTL from ClickHouse table ${table}"
  else
    sql="ALTER TABLE ${table} MODIFY TTL ${datetime_field} + toIntervalDay(${ttl})"
    msg="Setting TTL for ClickHouse table ${table}"
  fi

  upgrades.run_upgrade_checkpoint_command "${KCTL_BIN_DIR}/kctl run clickhouse-query '${sql}'" "${msg}"
}


postupgrade_checkpoint_2_42_6() {
  run_command "${KCTL_BIN_DIR}/kctl certificates fix-le-accounts" "Fixing LE accounts" hide_output
}

postupgrade_checkpoint_2_41_10() {
  rm -f /etc/keitaro/config/nginx.env
  find /var/www/keitaro/var/ -maxdepth 1 -type f -name 'stats.json-*.tmp' -delete || true
}

postupgrade_checkpoint_2_42_9() {
  local dir='/etc/keitaro/config'
  local cmd="rm -rf ${dir}/components.env ${dir}/components.local.env ${dir}/components"

  upgrades.run_upgrade_checkpoint_command "${cmd}" "Remove old env files"
}

postupgrade_checkpoint_2_42_8() {
  local cmd

  cmd="nohup /etc/cron.daily/kctl-certificates-renew &> /dev/null &"
  upgrades.run_upgrade_checkpoint_command "${cmd}" "Schedule renewing certificates"

  cmd="(${KCTL_BIN_DIR}/kctl podman stop certbot || true)"
  cmd="${cmd} && (${KCTL_BIN_DIR}/kctl podman prune certbot || true)"
  upgrades.run_upgrade_checkpoint_command "${cmd}" "Prune certbot containers"
}

preupgrade_checkpoint_2_41_7() {
  preupgrade_checkpoint_2_41_7.fix_db_engine
  preupgrade_checkpoint_2_41_7.fix_nginx_log_dir_permissions
}

preupgrade_checkpoint_2_41_7.fix_db_engine() {
  fix_db_engine
}

preupgrade_checkpoint_2_41_7.fix_nginx_log_dir_permissions() {
  local cmd
  local nginx_log_dir="/var/log/nginx"
  cmd="mkdir -p ${nginx_log_dir}"
  cmd="${cmd} && chown nginx:nginx ${nginx_log_dir}"
  cmd="${cmd} && chmod 0750 ${nginx_log_dir}"
  upgrades.run_upgrade_checkpoint_command "${cmd}" "Fixing nginx directory permissions"
}

fix_db_engine() {
  detect_db_engine() {
    local sql="SELECT lower(engine) FROM information_schema.tables WHERE table_name = 'schema_migrations'"
    if [[ -f /etc/keitaro/config/tracker.env ]]; then
      "${KCTL_BIN_DIR}"/kctl run mysql-query "${sql}"
    else
      /usr/bin/mysql "${VARS['db_name']}" -Nse "${sql}"
    fi
  }

  detect_db_engine_failsafe() {
    local tokudb_file_exists

    tokudb_file_exists="$(find /var/lib/mysql -maxdepth 1 -name '*tokudb' -printf 1 -quit)"

    if [[ "${tokudb_file_exists}" == "1" ]]; then
      echo "tokudb"
    else
      echo "innodb"
    fi
  }

  local detected_db_engine

  detected_db_engine="$(detect_db_engine || detect_db_engine_failsafe)"

  if [[ "${detected_db_engine}" != "tokudb" ]] && [[ "${detected_db_engine}" != "innodb" ]] ; then
    fail "Couldn't recognize current database engine - detected engine is '${detected_db_engine}'"
  fi

  upgrades.print_checkpoint_info "MariaDB tables engine is set to ${detected_db_engine}"
  VARS['db_engine']="${detected_db_engine}"
  write_inventory_file
}

preupgrade_checkpoint_2_41_8() {
  preupgrade_checkpoint_2_41_8.fix_db_engine
}

preupgrade_checkpoint_2_41_8.fix_db_engine() {
  if [[ "${VARS['db_engine']}" != "tokudb" ]] && [[ "${VARS['db_engine']}" != "innodb" ]]; then
    fix_db_engine
  fi
}
#
preupgrade_checkpoint_2_43_0() {
  components.install_binaries "kctl-ch-converter"
}

preupgrade_checkpoint_2_42_9() {
  components.install_binaries "kctld"
  components.install_binaries "roadrunner"
}

preupgrade_checkpoint_2_42_8() {
  preupgrade_checkpoint_2_42_8.install_components
}

preupgrade_checkpoint_2_42_8.install_components() {
  components.install "certbot-renew"
}

preupgrade_checkpoint_2_42_2() {
  preupgrade_checkpoint_2_42_2.install_components
}

preupgrade_checkpoint_2_42_2.install_components() {
  components.install "certbot"
  components.install "clickhouse"
  components.install "mariadb"
  components.install "nginx"
  components.install "redis"
}

UPGRADE_FN_SUFFIX="upgrade_checkpoint_"

upgrades.run_upgrade_checkpoints() {
  local upgrade_kind="${1}"
  local upgrade_fn_prefix="${upgrade_kind}${UPGRADE_FN_SUFFIX}"
  local version_str kctl_config_version message
  local kctl_config_version="${INSTALLED_VERSION}"

  if is_running_in_install_mode; then
    return
  fi

  for checkpoint_version in $(upgrades.list_checkpoint_versions "${upgrade_fn_prefix}" | versions.sort | uniq); do
    debug "kctl_config_version: ${kctl_config_version}, checkpoint_version: ${checkpoint_version}"
    if is_running_in_rescue_mode || versions.lte "${kctl_config_version}" "${checkpoint_version}"; then
      version_str="$(versions.patch "${checkpoint_version}")"
      upgrade_fn_name="${upgrade_fn_prefix}${version_str//./_}"

      print_with_color "Evaluating ${upgrade_kind}upgrade steps from v${version_str}" 'blue'
      debug "Evaluating ${upgrade_kind}upgrade steps from v${version_str}"

      debug "Evaluating ${upgrade_fn_name}()"
      if "${upgrade_fn_name}"; then
        print_with_color "Successfully evaluated ${upgrade_kind}upgrade steps from v${version_str}" "green"
        debug "Successfully evaluated ${upgrade_kind}upgrade steps from v${version_str}"
      else
        fail "Unexpected error while evaluating ${upgrade_kind}upgrade steps from v${version_str}"
      fi
    fi
  done
}

upgrades.list_checkpoint_versions() {
  local upgrade_fn_prefix="${1}"
  local checkpoint_versions upgrade_fns

  for upgrade_fn in $(upgrades.list_upgrade_fns "${upgrade_fn_prefix}"); do
    upgrades.extract_checkpoint_version "${upgrade_fn_prefix}" "${upgrade_fn}"
  done
}

upgrades.list_upgrade_fns() {
  local upgrade_fn_prefix="${1}"
  # `declare -F` shows all declared functions
  declare -F | awk '{print $3}' | grep "${upgrade_fn_prefix}" | grep -vF '.'
}

upgrades.extract_checkpoint_version() {
  local upgrade_fn_prefix="${1}" upgrade_fn="${2}"
  local upgrade_fn_prefix_length="${#upgrade_fn_prefix}"
  local version_str="${upgrade_fn:${upgrade_fn_prefix_length}}"

  echo "${version_str//_/.}"
}

upgrades.run_upgrade_checkpoint_command() {
  local cmd="${1}" msg="${2}"

  run_command "${cmd}" "  ${msg}" 'hide_output'
}

upgrades.print_checkpoint_info() {
  local msg="${1}" color="${2:-blue}"
  print_with_color "  ${msg}" "${color}"
  debug "${msg}"
}

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html

main(){
  init "$@"
  stage1 "$@"               # initial script setup
  stage2                    # make some asserts
  stage3                    # read vars from the inventory file
  stage4                    # get and save vars to the inventory file
  pushd "${TMPDIR}" &> /dev/null
  stage5                    # install kctl* scripts and related packages
  stage6                    # apply fixes
  stage7                    # run ansible playbook
  stage8                    # upgrade packages
  popd &> /dev/null || true
}

main "$@"
