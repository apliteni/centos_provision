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
TOOL_NAME='kctl'

SELF_NAME=${0}

is_ci_mode() {
  [[ "${CI}" != "" ]]
}

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

CACHING_PERIOD_IN_DAYS="2"
CACHING_PERIOD_IN_MINUTES="$((CACHING_PERIOD_IN_DAYS * 24 * 60))"

RELEASE_VERSION='2.45.2'
VERY_FIRST_VERSION='0.9'

FILES_KEITARO_ROOT_URL="https://files.keitaro.io"
RELEASE_API_BASE_URL="https://release-api.keitaro.io"

KEITARO_SUPPORT_USER='keitaro-support'
KEITARO_SUPPORT_HOME_DIR="/home/${KEITARO_SUPPORT_USER}"

UPDATE_CHANNEL_ALPHA="alpha"
UPDATE_CHANNEL_BETA="beta"
UPDATE_CHANNEL_STABLE="stable"
DEFAULT_UPDATE_CHANNEL="${UPDATE_CHANNEL_STABLE}"

UPDATE_CHANNELS=("${UPDATE_CHANNEL_ALPHA}" "${UPDATE_CHANNEL_BETA}" "${UPDATE_CHANNEL_STABLE}")

KCTL_COMPONENT="kctl"
TRACKER_COMPONENT="tracker"

PATH_TO_ENV_DIR="${ROOT_PREFIX}/etc/keitaro/env"
PATH_TO_COMPONENTS_ENV="${PATH_TO_ENV_DIR}/components.env"
PATH_TO_COMPONENTS_ENV_ORIGIN="${PATH_TO_ENV_DIR}/components.env.origin"
PATH_TO_COMPONENTS_ENVS_DIR="${PATH_TO_ENV_DIR}/components"
PATH_TO_APPLIED_ENV="${PATH_TO_ENV_DIR}/applied.env"
PATH_TO_INVENTORY_ENV="${PATH_TO_ENV_DIR}/inventory.env"
APPLIED_PREFIX="APPLIED"

declare -A VARS
declare -A ARGS
declare -A DETECTED_VARS

TRACKER_ROOT="${TRACKER_ROOT:-${ROOT_PREFIX}/var/www/keitaro}"

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
  ADDITIONAL_LOG_PATH="${LOG_DIR}/kctld-${LOG_FILENAME}"
fi


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

OLAP_DB_MARIADB="mariadb"
OLAP_DB_CLICKHOUSE="clickhouse"
OLAP_DB_DEFAULT="${OLAP_DB_MARIADB}"

KEITARO_USER='keitaro'
KEITARO_GROUP='keitaro'

KCTL_LIB_PATH="${ROOT_PREFIX}/var/lib/kctl"
# Check if lock file exist
#https://certbot.eff.org/docs/using.html#id5
#
assert_another_certbot_process_is_not_runing() {
  if [ -f "${CERTBOT_LOCK_FILE}" ]; then
    debug "Find lock file, raise error"
    fail "$(translate 'certbot_errors.another_proccess')"
  fi
}

assert_current_user_is_root() {
  if [[ "$EUID" != "$ROOT_UID" ]]; then
    fail "$(translate errors.must_be_root)"
  fi
}

assert_same_process_is_not_running() {
  exec 8>/var/run/${SCRIPT_NAME}.lock

  if ! flock -n -x 8; then
    fail "$(translate 'errors.already_running')" "${INTERRUPTED_ON_PARALLEL_RUN}"
  fi
}

check_assertion() {
  local name="${1}" fn_name

  fn_name="${name,,}"
  fn_name="${fn_name// /_}"
  fn_name="assert_${fn_name}"

  if system.list_defined_fns | grep -q "^${fn_name}$"; then
    ${fn_name}
    debug "Assertion '${name}' is passed"
  else
    fail "Couldn't find fn ${fn_name}() for checking assertion '${name}'"
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

arrays.add() {
  local value="${1}"; shift
  local array=("${@}")

  array+=("${value}")

  echo "${array[@]}"
}

arrays.in() {
  local value="${1}"; shift
  local array=("${@}")

  [[ "$(arrays.index_of "${value}" "${array[@]}")" != "" ]]
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

arrays.remove() {
  local value="${1}"; shift
  local array=("${@}")

  value_index="$(arrays.index_of "${value}" "${array[@]}")"

  if [[ "${value_index}" != "" ]]; then
    unset 'array[value_index]'
  fi

  echo "${array[@]}"
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
    print_with_color "  Skip downloading ${url} - got from cached ${path}" 'blue'
  else
    debug "Downloading ${url}"
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
  print_with_color "  Downloading ${url} " 'blue'

  path="$(cache.path_by_url "${url}")"
  tmp_path="${path}.tmp"

  dir="${path%/*}"

  mkdir -p "${dir}"

  if requests.get "${url}" "${tmp_path}" "${tries}"; then
    mv "${tmp_path}" "${path}"
    debug "Successfully downloaded to ${path}"
    print_with_color "  Successfully downloaded to ${path}" 'blue'
  else
    fail "Couldn't download ${url}"
  fi
}

build_certbot_command() {
  echo "LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run certbot"
}

certbot.register_account() {
  local cmd
  cmd="$(build_certbot_command) register"
  cmd="${cmd} --agree-tos --non-interactive --register-unsafely-without-email"

  run_command "${cmd}" "Creating certbot account" "hide_output"
}

components.assert_var_is_set() {
  local component="${1}" variable="${2}" component_var value

  value="$(components.read_var "${component}" "${variable}")"

  if [[ "${value}" == "" ]]; then
    component_var="$(components.get_var_name "${component}" "${variable}")"
    fail "${component_var} is not set!"
  fi
}

components.build_path_to_preinstalled_directory() {
  local component="${1}" version url url_hash

  version="$(components.read_var "${component}" 'version')"
  url="$(components.read_var "${component}" 'url')"
  url_hash="$(md5sum <<< "${url}" | awk '{print $1}')"

  echo "${KCTL_LIB_PATH}/${component}/${version}/${url_hash}"
}

components.create_group() {
  local component="${1}"
  local group group_id cmd

  group_id="$(components.detect_group_id "${component}")"
  if [[ "${group_id}" != "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "group"
  group="$(components.read_var "${component}" "group")"

  cmd="groupadd --system ${group}"
  run_command "${cmd}" "  Creating group ${group}" 'hide_output'
}

components.create_user() {
  local component="${1}"
  local user group user_id home cmd

  user_id="$(components.detect_user_id "${component}")"
  if [[ "${user_id}" != "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "user"
  user="$(components.read_var "${component}" "user")"

  components.assert_var_is_set "${component}" "group"
  group="$(components.read_var "${component}" "group")"

  components.assert_var_is_set "${component}" "home"
  home="$(components.read_var "${component}" "home")"

  cmd="useradd --no-create-home --system --home-dir ${home} --shell /sbin/nologin --gid ${group} ${user}"
  run_command "${cmd}" "  Creating user ${user}" 'hide_output'
}

COMPONENTS_OWN_VOLUMES_PREFIXES="/var/cache/ /var/log/ /var/lib/"

components.create_volumes() {
  local component="${1}" user group volumes

  volumes="$(components.read_var "${component}" "volumes")"
  if [[ "${volumes}" == "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "user"
  user="$(components.read_var "${component}" "user")"

  components.assert_var_is_set "${component}" "group"
  group="$(components.read_var "${component}" "group")"

  for volume in ${volumes}; do
    components.create_volumes.init_volume "${volume}" "${user}" "${group}"
  done
}

components.create_volumes.init_volume() {
  local volume="${1}" user="${2}" group="${3}" host_path
  host_path="${volume%:*}"

  if [[ ! "${host_path}" =~ /$ ]]; then
    return
  fi

  if [[ ! -d "${host_path}" ]]; then
    mkdir -p "${host_path}"
  fi

  for own_volume_prefix in ${COMPONENTS_OWN_VOLUMES_PREFIXES}; do
    if [[ "${host_path}" =~ ^${own_volume_prefix} ]]; then
      chown "${user}:${group}" "${host_path}"
    fi
  done
}

components.detect_group_id() {
  local component="${1}" group

  components.assert_var_is_set "${component}" "group"
  group="$(components.read_var "${component}" "group")"

  (getent group "${group}" | awk -F: '{print $3}') 2>/dev/null || true
}

components.detect_user_id() {
  local component="${1}" user

  components.assert_var_is_set "${component}" "user"
  user="$(components.read_var "${component}" "user")"

  id -u "${user}" 2>/dev/null || true
}

components.get_var_name() {
  local component="${1}" var="${2}"

  env_files.normalize_var_name "${component}_${var}"
}

components.has_var() {
  local component="${1}"
  local variable="${2}"
  local component_var; component_var="$(components.get_var_name "${component}" "${variable}")"
  local path_to_env_file; path_to_env_file="$(components.path_to_env_file "${component}" "${variable}")"

  env_files.has_var "${path_to_env_file}" "${component_var}"
}

components.install_binaries() {
  local component="${1}" version src_dir dst_dir msg

  components.preinstall "${component}"

  version="$(components.read_var "${component}" "version")"

  src_dir="$(components.build_path_to_preinstalled_directory "${component}")"
  dst_dir="$(components.read_var "${component}" "working_directory")"

  if [[ "${dst_dir}" == "" ]]; then
    msg="Working directory for ${component} v${version} is not set, skip installing files"
    debug "${msg}"; print_with_color "${msg}" 'blue'
    return
  fi

  msg="Installing ${component} v${version} to ${dst_dir}"
  debug "${msg}"; print_with_color "  ${msg}" 'blue'

  # shellcheck disable=SC2044
  for path_to_bin_file in $(find "${src_dir}" -maxdepth 1 -perm -u=x -type f); do
    local bin_file="${path_to_bin_file##*/}"
    local bin_file_versioned="${bin_file}-${version}"

    cmd="rm -f ${dst_dir}/${bin_file} ${dst_dir}/${bin_file}-*"                         # uninstall old
    cmd="${cmd} && /bin/cp -f ${src_dir}/${bin_file} ${dst_dir}/${bin_file_versioned}"  # install new
    cmd="${cmd} && ln -s ${dst_dir}/${bin_file_versioned} ${dst_dir}/${bin_file}"       # make symlink
    run_command "${cmd}" "  Installing ${bin_file}" "hide_output"
  done
}

components.install_image() {
  local component="${1}" version

  version="$(components.read_var "${component}" 'version')"
  debug "Installing ${component} v${version} component"
  print_with_color "Installing component ${component} v${version}" 'blue'

  components.create_group "${component}"
  components.create_user "${component}"
  components.create_volumes "${component}"
  components.pull "${component}"
}

components.is_changed() {
  local component="${1}"

  components.is_variable_changed "${component}" 'image' \
    ||  components.is_variable_changed "${component}" 'url'
}

components.is_common_variable() {
  local variable="${1}"

  [[ "${variable}" == 'version' ]] \
    || [[ "${variable}" == 'image' ]] \
    || [[ "${variable}" == 'url' ]]
}

components.is_installed() {
  local component="${1}"

  local applied_url; applied_url="$(components.read_applied_var "${component}" 'url')"
  local applied_image; applied_image="$(components.read_applied_var "${component}" 'image')"
  [[ "${applied_url}" != '' || "${applied_image}" != '' ]]
}

components.is_variable_changed() {
  local component="${1}" variable="${2}" value applied_value

  value="$(components.read_var "${component}" "${variable}")"
  applied_value="$(components.read_applied_var "${component}" "${variable}")"

  [[ "${value}" != "${applied_value}" ]]
}

components.list_applied() {
  components.list_defined_in_env_file $PATH_TO_APPLIED_ENV
}

components.list_defined_in_env_file() {
  local env_file_path="${1}"

  # 1. List all defined vars
  # 2. Keep only vars ended with _VERSION, remove _VERSION from name
  # 3. Remove APPLIED_ prefix
  # 4. Convert var name to component name (e.g. KCTL_CH_CONVERTER to kctl-ch-converter)
  # 5. Remove keitaro component
  env_files.list_vars "${env_file_path}" \
          | grep -oP '^.+(?=_VERSION)' \
          | sed 's/^APPLIED_//g' \
          | tr 'A-Z_' 'a-z\-' \
          | grep -v keitaro
}

components.list_origin() {
  components.list_defined_in_env_file $PATH_TO_COMPONENTS_ENV_ORIGIN
}

components.list_protected() {
  env_files.read_origin_var "components_protected_from_downgrade"
}

components.list_redundant() {
  local origin_components
  # shellcheck disable=SC2207
  origin_components=( $(components.list_origin) )

  for applied_component in $(components.list_applied | tac); do
    if ! arrays.in "${applied_component}" "${origin_components[@]}"; then
      echo "${applied_component}"
    fi
  done
}

components.normalize_name() {
  local name="${1}"
  name="${name,,}"

  echo "${name//[^[:alnum:]]/-}"
}

components.path_to_env_file_with_extra_vars() {
  local component="${1}"

  local file_name; file_name="$(env_files.normalize_file_name "${component}")"
  echo "${PATH_TO_COMPONENTS_ENVS_DIR}/${file_name}.env"
}

components.path_to_env_file() {
  local component="${1}"
  local variable="${2}"

  if components.is_common_variable "${variable}"; then
    echo "${PATH_TO_COMPONENTS_ENV}"
  else
    components.path_to_env_file_with_extra_vars "${component}"
  fi
}

components.preinstall() {
  local component="${1}" url version directory user group cmd base_directory unpack_cmd msg

  version="$(components.read_var "${component}" 'version')"
  url="$(components.read_var "${component}" 'url')"
  directory="$(components.build_path_to_preinstalled_directory "${component}")"
  user="$(components.read_var "${component}" 'user')"

  msg="Preinstalling component ${component} v${version} from ${url}"
  debug "${msg}"; print_with_color "${msg}" 'blue'

  cache.retrieve_or_download "${url}"

  unpack_cmd="$(components.preinstall.build_unpack_cmd "${component}" "${version}" "${url}" "${directory}")"

  if [[ -d "${directory}" ]]; then
    cmd="rm -rf ${directory} &&"
  fi

  if [[ "${user}" != "" ]] && [[ "${user}" != 'root' ]]; then
    components.create_group "${component}"
    components.create_user "${component}"
  fi

  cmd="${cmd} mkdir -p ${directory} &&"
  cmd="${cmd} ${unpack_cmd}"

  run_command "${cmd}" "  Unpacking ${component} v${version} to ${directory}" "hide_output"
}

components.preinstall.build_unpack_cmd() {
  local component="${1}" version="${2}" url="${3}" directory="${4}" path

  path="$(cache.path_by_url "${url}")"

  if [[ "${path}" =~ \.zip$ ]]; then
    echo "unzip -q ${path} -d ${directory}"
  elif [[ "${path}" =~ \.tar\.gz$ ]]; then
    echo "tar -xz --no-same-owner --no-same-permissions -f ${path} -C ${directory}"
  fi
}

components.pull() {
  local component="${1}" image

  components.assert_var_is_set "${component}" "image"
  image="$(components.read_var "${component}" "image")"

  run_command "podman pull ${image}" "  Pulling ${component} image" "hide_output"
}

components.read_applied_var() {
  local component="${1}"
  local variable="${2}"
  local component_var

  component_var="$(components.get_var_name "${component}" "${variable}")"

  env_files.read_applied_var "${component_var}"
}

components.read_origin_var() {
  local component="${1}"
  local variable="${2}"
  local component_var

  component_var="$(components.get_var_name "${component}" "${variable}")"

  env_files.read_origin_var "${component_var}"
}

components.read_var() {
  local component="${1}"
  local variable="${2}"
  local component_var; component_var="$(components.get_var_name "${component}" "${variable}")"

  if components.is_common_variable "${variable}" && [[ "${!component_var:-}" != "" ]]; then
    echo "${!component_var}"
  else
    local path_to_env_file; path_to_env_file="$(components.path_to_env_file "${component}" "${variable}")"
    env_files.read_var "${path_to_env_file}" "${component_var}"
  fi
}

components.run() {
  local component="${1}" container_name="${2}" podman_extra_args="${3}"; shift 3 || true
  local image volumes_args volumes cmd

  components.assert_var_is_set "${component}" "image"
  image="$(components.read_var "${component}" "image")"

  volumes="$(components.read_var "${component}" "volumes")"

  for volume_path in ${volumes}; do
    local source_path="${volume_path%:*}"
    local target_path="${volume_path##*:}"

    volumes_args="${volumes_args} -v ${source_path}:${target_path}"
  done

  cmd="podman run --rm --net host --name ${container_name} --cap-add CAP_NET_BIND_SERVICE"
  cmd="${cmd} ${volumes_args} ${podman_extra_args} ${image} ${*}"
  cmd="$(echo "${cmd}" | sed -r "s/_PASSWORD=[^ ]+/_PASSWORD=***MASKED***/g")"
  debug "Running \`${cmd}\`"

  # shellcheck disable=SC2086
  exec /usr/bin/podman run \
                           --rm \
                           --net host \
                           --name "${container_name}" \
                           --cap-add=CAP_NET_BIND_SERVICE \
                           ${volumes_args} \
                           ${podman_extra_args} \
                           "${image}" \
                           "${@}"
}

components.uninstall() {
  local component="${1}" path_to_env_file

  print_with_color "Uninstalling ${component}" 'blue'

  for service in $(components.read_var "${component}" "services"); do
    systemd.uninstall "${service}"
  done
  for suffix in version url image; do
    env_files.remove_var "${PATH_TO_APPLIED_ENV}" "applied-${component}-${suffix}"
  done
  path_to_env_file="$(components.path_to_env_file_with_extra_vars "${component}")"
  if [[ -f "${path_to_env_file}" ]]; then
    run_command "rm -f ${path_to_env_file}" "Removing ${component}'s env file"
  fi
}

components.update_applied_vars() {
  local component="${1}"

  for var_name in version image url; do
    components.update_applied_vars.update_var "${component}" "${var_name}"
  done
}

components.update_applied_vars.update_var() {
  local component="${1}" var_name="${2}" value

  value="$(components.read_var "${component}" "${var_name}")"

  if [[ "${value}" != "" ]]; then
    components.update_applied_vars.save_var "${component}" "${var_name}" "${value}"
  fi
}

components.update_applied_vars.save_var() {
  local component="${1}" var_name="${2}" value="${3}" component_var

  component_var="$(components.get_var_name "${component}" "${var_name}")"

  env_files.save_applied_var "${component_var}" "${value}"
}

ALIVENESS_PROBES_NO=10

components.wait_until_is_up() {
  local component="${1}" msg

  if is_ci_mode || components.is_alive "${component}"; then
    return
  fi

  print_with_color "  Waiting for a component ${component} to start accepting connections"  "blue"

  for ((i=0; i<ALIVENESS_PROBES_NO; i++)); do
    local sleep_in_sec=$((ALIVENESS_PROBES_NO + 1))
    sleep "${sleep_in_sec}"
    if components.is_alive "${component}"; then
      print_with_color "  Component ${component} is accepting connections"  "green"
      return
    else
      print_with_color "    Try $(( i + 1 ))/${ALIVENESS_PROBES_NO} - no connect" "yellow"
    fi
  done

  fail "Component ${component} is not accepting connections"
}

components.is_alive() {
  local component="${1}" host port

  host="$(components.read_var "${component}" "host")"
  port="$(components.read_var "${component}" "port")"

  if [[ "${host}" == "" ]] || [[ "${port}" == "" ]]; then
    return
  fi

  timeout 0.1 bash -c "</dev/tcp/${host}/${port}" &>/dev/null
}

components.with_services_do() {
  local component="${1}" action="${2}"

  for service in $(components.read_var "${component}" "services"); do
    systemd.with_service_do "${service}" "${action}"
  done
}

env_files.assert_is_set() {
  local path_to_env_file="${1}" var_name="${2}" value

  value="$(env_files.read_var "${path_to_env_file}" "${var_name}")"

  if [[ "${value}" == "" ]]; then
    fail "Variable ${var_name} is not set in the ${path_to_env_file}"
  fi
}

env_files.forced_save_var() {
  local path_to_env_file="${1}" var_name="${2}" var_value="${3}"
  local normalized_var_name; normalized_var_name="$(env_files.normalize_var_name "${var_name}")"

  if env_files.has_var "${path_to_env_file}" "${var_name}"; then
    { sed -e "/^${normalized_var_name}=/d" "${path_to_env_file}" > "${path_to_env_file}.tmp" \
      && echo "${normalized_var_name}=${var_value}" >> "${path_to_env_file}.tmp" \
      && mv "${path_to_env_file}.tmp" "${path_to_env_file}" ; } \
          || fail "Couldn't change ${normalized_var_name} in the ${path_to_env_file}"

  else
    echo "${normalized_var_name}=${var_value}" >> "${path_to_env_file}" \
      || fail "Couldn't save ${normalized_var_name} to the ${path_to_env_file}"
  fi

  debug "Saved ${normalized_var_name}='$(strings.mask "${normalized_var_name}" "${var_value}")' to ${path_to_env_file}"
}

env_files.has_var() {
  local path_to_env_file="${1}" var_name="${2}"
  local normalized_var_name; normalized_var_name="$(env_files.normalize_var_name "${var_name}")"

  [[ -f "${path_to_env_file}" ]] && grep -qP "^${normalized_var_name}=" "${path_to_env_file}"
}


env_files.list_vars() {
  local env_file_path="${1}"

  if [[ -f "${env_file_path}" ]]; then
    grep -oP "^[[:alpha:]][[:alnum:]_]*(?==)" "${env_file_path}"
  fi
}

env_files.normalize_file_name() {
  local var_name="${1,,}"

  echo "${var_name//_/-}"
}

env_files.normalize_var_name() {
  local var_name="${1^^}"

  echo "${var_name//[^[:alnum:]]/_}"
}

env_files.read_applied_var() {
  local variable="${1}"
  env_files.read_var "${PATH_TO_APPLIED_ENV}" "${APPLIED_PREFIX}_${variable}"
}

env_files.read_origin_var() {
  local variable="${1}"
  env_files.read_var "${PATH_TO_COMPONENTS_ENV_ORIGIN}" "${variable}"
}

env_files.read_var() {
  local path_to_env_file="${1}" var_name="${2}"
  local normalized_var_name; normalized_var_name="$(env_files.normalize_var_name "${var_name}")"

  if [[ -f "${path_to_env_file}" ]]; then
    cmd="source ${path_to_env_file}"

    if [[ "${path_to_env_file}" =~ .env$ ]]; then
      local path_to_local_env_file="${path_to_env_file::-4}.local.env"
      if [[ -f "${path_to_local_env_file}" ]]; then
       cmd="${cmd} && source ${path_to_local_env_file}"
      fi
    fi
    cmd="${cmd} && echo \"\$${normalized_var_name}\""
    bash -c "${cmd}"
  fi
}

env_files.remove_var() {
  local path_to_env_file="${1}" var_name="${2}"
  local normalized_var_name; normalized_var_name="$(env_files.normalize_var_name "${var_name}")"

  if env_files.has_var "${path_to_env_file}" "${var_name}"; then
    sed -i -e "/^${normalized_var_name}=/d" "${path_to_env_file}" \
      || fail "Couldn't remove ${normalized_var_name} from the ${path_to_env_file}"
  fi

  debug "Removed ${normalized_var_name} from ${path_to_env_file}"
}

env_files.safely_save_var() {
  local env_file_name="${1}" var_name="${2}" var_value="${3}"

  if ! env_files.has_var "${env_file_name}" "${var_name}"; then
    env_files.forced_save_var "${env_file_name}" "${var_name}" "${var_value}"
  fi
}


env_files.save_applied_var() {
  local var_name="${1}" value="${2}"
  env_files.forced_save_var "${PATH_TO_APPLIED_ENV}" "${APPLIED_PREFIX}_${var_name}" "${value}"
}

gathering.gather_cpu_cores() {
  grep -c ^processor /proc/cpuinfo
}

gathering.gather_cpu_frequency_mhz() {
  awk -F': ' '/^cpu MHz/ {print $2}' /proc/cpuinfo | head -n1 2>/dev/null
}

gathering.gather_cpu_name() {
  awk -F': ' '/^model name/ {print $2}' /proc/cpuinfo | head -n1 2>/dev/null
}

gathering.gather_disk_free_size_mb() {
  (df -m --output=avail / | tail -n1) 2>/dev/null
}

gathering.gather_ram_size_mb() {
  free -m | awk '/^Mem:/ { print $2 }' | head -n1
}

MYIP_KEITARO_IO="https://myip.keitaro.io"

gathering.gather_server_ip() {
  curl -fsSL "${MYIP_KEITARO_IO}"
}

gathering.gather_ssh_port() {
  /usr/sbin/ss -l -4 -p -n | grep -w tcp | grep -w sshd | awk '{ print $5 }' | awk -F: '{ print $2 }' | head -n1
}

gathering.gather_swap_size_mb() {
  { free -m | grep Swap: | awk '{print $2}'; } 2>/dev/null
}

gathering.gather_virtualization_type() {
  hostnamectl status | awk '/Virtualization:/ { print $2 }'
}

gathering.gather() {
  local var_name="${1}"

  if ! gathering.is_gatherable "${var_name}"; then
    fail "Couldn't gather hw var ${var_name}: there is no defined fn ${fn_name}"
  fi

  local fake_value; fake_value="$(gathering.gather.get_fake_value "${var_name}")"
  if [[ "${fake_value}" != "" ]]; then
    debug "Got ${var_name} from $(gathering.gather.get_fake_env_var_name "${var_name}") env var: ${fake_value}"
    echo "${fake_value}"
  else
    local fn_name="gathering.gather_${var_name}"
    ${fn_name}
  fi

}

gathering.gather.get_fake_value() {
  local var_name="${1}" fake_env_var_name

  fake_env_var_name="$(gathering.gather.get_fake_env_var_name "${var_name}")"
  echo "${!fake_env_var_name:-}"
}

gathering.gather.get_fake_env_var_name() {
  local var_name="${1}"
  env_files.normalize_var_name "fake_${var_name}"
}

gathering.is_gatherable() {
  local var_name="${1}" fn_name_regex
  fn_name_regex="gathering\\.gather_${var_name}"

  system.list_defined_fns | grep -q "^${fn_name_regex}$"
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

inventory.has_var() {
  local variable="${1}"

  env_files.has_var "${PATH_TO_INVENTORY_ENV}" "${variable}"
}

inventory.is_variable_changed() {
  local variable="${1}" value applied_value

  value="$(inventory.read_var "${variable}")"
  applied_value="$(env_files.read_applied_var "${variable}")"

  [[ "${value}" != "${applied_value}" ]]
}

inventory.read_var() {
  local var_name="${1}"
  env_files.read_var "${PATH_TO_INVENTORY_ENV}" "${var_name}"
}

inventory.save_var() {
  local var_name="${1}" value="${2}"
  env_files.forced_save_var "${PATH_TO_INVENTORY_ENV}" "${var_name}" "${value}"
}

inventory.update_applied_var() {
  local var_name="${1}" value

  value="$(inventory.read_var "${var_name}")"
  env_files.save_applied_var "${var_name}" "${value}"
}

add_indentation(){
  sed -r "s/^/${INDENTATION_SPACES}/g"
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

requests.get() {
  local url="${1}" save_to="${2:-"-"}" tries="${3:-${DOWNLOADING_TRIES}}"

  debug "Start getting ${url}"

  for ((i=1; i<tries+1; i++)); do
    local connect_timeout="$(( 2*(i-1) + 1 ))"

    debug "Try #${i}/${tries}: \`curl -fsSL4 ${url} --connect-timeout ${connect_timeout} -o ${save_to}\`"

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

clean_up() {
  true
}

debug() {
  local message="${1}"
  if [[ "${LOG_PATH}" == "/dev/stderr" ]]; then
    echo "$message" >&2
  else
    echo "$message" >> "${LOG_PATH}"
  fi
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
  if [[ ! -d "${PATH_TO_ENV_DIR}" ]]; then
    if ! mkdir -p "${PATH_TO_ENV_DIR}"; then
      echo "Can't create keitaro env directory ${PATH_TO_ENV_DIR}" >&2
    fi
  fi
}

create_kctl_dirs_and_links() {
  mkdir -p "${LOG_DIR}" "${SSL_LOG_DIR}" "${PATH_TO_ENV_DIR}" "${KCTL_BIN_DIR}" "${WORKING_DIR}" &&
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

init() {
  init_kctl
  debug "Command: ${SCRIPT_NAME} ${TOOL_ARGS}"
  debug "Script version: ${RELEASE_VERSION}"
  debug "Current date time: $(date +'%Y-%m-%d %H:%M:%S %:z')"
  trap on_exit SIGHUP SIGTERM
  trap on_exit_by_user_interrupt SIGINT
}

system.is_keitaro_installed() {
  [[ -f "${PATH_TO_APPLIED_ENV}" ]]
}

system.list_defined_fns() {
  declare -F | awk '{print $3}'
}

log_and_print_err(){
  local message="${1}"
  debug "$message"
  if [[ "${KCTLD_MODE}" == "" ]]; then
    print_err "$message" 'red'
  fi
}

on_exit_by_user_interrupt(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')" "${INTERRUPTED_BY_USER_RESULT}"
}

on_exit(){
  debug "Terminated by user"
  echo
  clean_up
  fail "$(translate 'errors.terminated')"
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

systemd.daemon_reload() {
  run_command 'systemctl daemon-reload' "Updating SystemD units" "hide_output"
}

systemd.disable_and_stop_service() {
  local name="${1}"
  systemd.disable_service "${name}"
  systemd.stop_service "${name}"
}

systemd.disable_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'disable'
}

systemd.enable_and_start_service() {
  local name="${1}"
  systemd.enable_service "${name}"
  systemd.start_service "${name}"
}

systemd.enable_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'enable'
}

systemd.get_full_service_name() {
  local service_name="${1}" full_service_name

  if [[ "${service_name}" =~ \. ]]; then
    full_service_name="${service_name}"
  else
    full_service_name="${service_name}.service"
  fi

  echo "${full_service_name}"
}

systemd.get_service_file_name() {
  local service_name="${1}"
  local file_name; file_name="$(systemd.get_full_service_name "${service_name}")"

  if [[ "${file_name}" =~ @[^\.] ]]; then
    file_name="${file_name//@[^\.]/@}"
  fi

  echo "${file_name}"
}

systemd.is_service_installed() {
  local service_name="${1}"
  local service_file_name; service_file_name="$(systemd.get_service_file_name "${service_name}")"

  systemd.list_unit_files | grep -q "^${service_file_name}$"
}

systemd.list_unit_files() {
  systemctl list-unit-files --plain --no-pager --no-legend --full | awk '{print $1}'
}

systemd.reload_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'reload'
}

systemd.restart_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'restart'
}

systemd.start_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'start'
}

systemd.stop_service() {
  local service_name="${1}"
  systemd.with_service_do "${service_name}" 'stop'
}

systemd.uninstall() {
  local service_name="${1}"
  systemd.disable_and_stop_service "${service_name}"
  systemd.uninstall.remove_self_and_dependent_services_files "${service_name}"
}

systemd.uninstall.remove_self_and_dependent_services_files() {
  local service_name="${1}" dependent_service_name

  for dependent_service_name in $(systemd.list_dependent_services "${service_name}"); do
    systemd.uninstall.remove_self_and_dependent_services_files "${dependent_service_name}"
  done

  systemd.uninstall.remove_files "${service_name}"
}

systemd.list_dependent_services() {
  local service_name="${1}"
  local full_service_name; full_service_name="$(systemd.get_full_service_name "${service_name}")"

  # 1. List dependencies w/ SystemD appropriate command
  # 2. Keep only first level deps
  # 3. Remove system deps
  systemctl list-dependencies "${full_service_name}" --no-pager \
          | grep -v '  ' | grep -Po '(?<=^[^[:alnum:]]{4})[[:alnum:]].*' \
          | grep -v ^sysinit.target | grep -v ^system
}

systemd.uninstall.remove_files() {
  local service_name="${1}"
  local file_name; file_name="$(systemd.get_service_file_name "${service_name}")"
  local path_to_systemd_service="/etc/systemd/system/${file_name}"

  if [[ -f "${path_to_systemd_service}" ]]; then
    local cmd="rm -f '${path_to_systemd_service}'"
    if [[ -d "${path_to_systemd_service}.d" ]]; then
      cmd="${cmd} && rm -rf '${path_to_systemd_service}.d'"
    fi
    cmd="${cmd} && systemctl daemon-reload"
    cmd="${cmd} && systemctl reset-failed"
    run_command "${cmd}" "Uninstalling ${file_name} SystemD unit file"
  else
    print_with_color "Skip uninstalling ${file_name} SystemD unit file: nothing to remove" "yellow"
  fi
}

systemd.with_service_do() {
  local service_name="${1}" systemctl_command="${2}" action_description msg

  action_description="$(strings.add_suffix "${systemctl_command}" 'ing')"

  if systemd.is_service_installed "${service_name}"; then
    run_command "systemctl ${systemctl_command} '${service_name}'" \
                "${action_description^} SystemD service ${service_name}" \
                "hide_output"
  else
    msg="Skip ${action_description} ${service_name} because it is not installed"
    print_with_color "${msg}" 'yellow'; debug "${msg}"
  fi
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
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='Please run this program as root.'
DICT['en.errors.run_command.fail']='There was an error evaluating current command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.errors.unexpected']='Unexpected error'
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

kctl_auto_install(){
  local install_args="${1}"
  local log_file="${2}"
  local install_exit_code
  local sleeping_message

  if empty "${KCTLD_MODE}"; then
    for (( count=0; count<=${#RETRY_INTERVALS[@]}; count++ ));  do
      if kctl_install "${install_args}" "${log_file}"; then
        installator_exit_code="${?}"
      else
        installator_exit_code="${?}"
      fi
      debug "Result code is '${installator_exit_code}'"

      if [[ "${installator_exit_code}" == "0" ]]; then
        return "${SUCCESS_RESULT}"
      fi

      if (( "${installator_exit_code}" >= "200" )); then
        return "${installator_exit_code}"
      fi

      if [[ "$count" == "${#RETRY_INTERVALS[@]}" ]]; then
        fail "$(translate errors.unexpected)"
      else
        sleeping_message="$(translate "messages.sleeping_before_next_try" "retry_interval=${RETRY_INTERVALS[$count]}")"
        echo "${sleeping_message}" >&2
        debug "${sleeping_message}"
        sleep "${RETRY_INTERVALS[$count]}"
      fi
    done
  else
    kctl_install "${install_args}" "${log_file}"
  fi
}

kctl_install(){
  local install_args="${1}"
  local log_file="${2}"

  if [[ ! -f "${PATH_TO_COMPONENTS_ENV}" ]]; then # too old kctl is installed or no kctl
    debug "Running \`curl -fsSL4 'https://keitaro.io/install.sh' | bash -s -- ${install_args}\`"
    curl -fsSL4 'https://keitaro.io/install.sh' | LOG_PATH="${KCTL_LOG_DIR}/${log_file}" bash -s -- "${install_args}"
  else
    debug "Running \`LOG_PATH='${KCTL_LOG_DIR}/${log_file}' ${KCTL_BIN_DIR}/kctl-install ${install_args}\`"
    LOG_PATH="${KCTL_LOG_DIR}/${log_file}" "${KCTL_BIN_DIR}/kctl-install" "${install_args}"
  fi
}

kctl_install_tracker() {
  local arg="${1}"
  local log_path="${KCTL_LOG_DIR}/kctl-install-tracker.log"

  local tracker_version="${TRACKER_VERSION:-}" tracker_url="${TRACKER_URL:-}"

  if [[ "${arg}" == "latest" ]]; then
    tracker_url="${arg}"
  elif [[ "${arg}" == "latest-stable" ]]; then
    update_channel="${UPDATE_CHANNEL_STABLE}"
  elif [[ "${arg}" == "latest-unstable" ]]; then
    update_channel="${UPDATE_CHANNEL_BETA}"
  elif [[ "${arg}" =~ ^https:\/\/files.keitaro.io\/ ]]; then
    tracker_url="${arg}"
  else
    tracker_version="${arg}"
  fi

  LOG_PATH="${log_path}" UPDATE_CHANNEL="${update_channel}" TRACKER_URL="${tracker_url}" \
    TRACKER_VERSION="${tracker_version}" SKIP_CACHE=true "${KCTL_BIN_DIR}/kctl-install" -U
}
kctl.reset() {
  kctl.reset.machine_id
  kctl.reset.db_component 'mariadb'
  kctl.reset.db_component 'clickhouse'
  kctl.reset.tracker
  print_with_color 'Reset completed' 'green'
}

kctl_show_help(){
  echo "kctl - Keitaro management tool"
  echo ""
  cat <<-END
Usage:

  kctl [module] [action] [options]

Example:

  kctl install

Actions:
  kctl check                      - checks if all componets operates normally
  kctl downgrade                  - installs the latest stable tracker version
  kctl install                    - installs tracker and system components
  kctl repair                     - fixes common problems
  kctl tune                       - tunes all components
  kctl update                     - updates system & tracker (you have to to set UPDATE_CHANNEL or KEITARO_VERSION)
  kctl use-clickhouse-olapdb      - configures Keitaro to use ClickHouse as OLAP DB

Modules:
  kctl certificates               - manage LE certificates
  kctl podman                     - manage podman containers
  kctl resolvers                  - manage DNS resolvers
  kctl run                        - simplifies running dockerized commands
  kctl support-team-access        - allow/deny access to this server to Keitaro support team
  kctl tracker-options            - manage tracker options
  kctl transfers                  - manage tracker data transfers

END
}

kctl_show_version() {
  if system.is_keitaro_installed; then
    kctl_show_version.show_component_version 'keitaro'
    for component in $(components.list_origin); do
      if [[ "${component}" != "nginx-starting-page" ]]; then
        kctl_show_version.show_component_version "${component}"
      fi
    done
    kctl_show_version.show_inventory_var 'MariaDB Storage Engine'
    kctl_show_version.show_inventory_var 'OLAP DB'
    kctl_show_version.show_gatherable_var 'CPU Cores'
    kctl_show_version.show_gatherable_var 'RAM Size MB'
    kctl_show_version.show_value "OS" "$(kctl_show_version.get_pretty_os_name)"
    kctl_show_version.show_value "SELinux Status" "$(kctl_show_version.detect_selinux_status)"
  else
    fail "$(translate 'errors.tracker_is_not_installed')"
  fi
}

kctl_show_version.show_gatherable_var() {
  local description="${1}"
  local variable; variable="$(strings.underscore "${description}")"
  local current_value; current_value="$(gathering.gather "${variable}")"
  local applied_value; applied_value="$(env_files.read_applied_var "${variable}")"
  kctl_show_version.show_complex_value "${description}" "${current_value}" "${applied_value}"
}

kctl_show_version.show_inventory_var() {
  local description="${1}"
  local variable; variable="$(strings.underscore "${description}")"
  local current_value; current_value="$(inventory.read_var "${variable}")"
  local applied_value; applied_value="$(env_files.read_applied_var "${variable}")"
  kctl_show_version.show_complex_value "${description}" "${current_value}" "${applied_value}"
}

kctl_show_version.show_component_version() {
  local component="${1}"
  local description; description="$(components.read_var "${component}" "human_name")"
  if [[ "${description}" == "" ]]; then
    description="${component^}"
  fi
  local current_value; current_value="$(components.read_var "${component}" 'version')"
  local applied_value; applied_value="$(components.read_applied_var "${component}" 'version')"
  local origin_value; origin_value="$(components.read_origin_var "${component}" 'version')"
  if [[ "${current_value}" == "${applied_value}" ]] && [[ "${current_value}" != "${origin_value}" ]]; then
    if arrays.in "${component}" "$(components.list_protected)"; then
      current_value="${current_value}* (protected from downgrading to ${origin_value})"
      applied_value="${current_value}"
    fi
  fi
  kctl_show_version.show_complex_value "${description}" "${current_value}" "${applied_value}"
}

kctl_show_version.show_value() {
  local description="${1}" value="${2}"
  local padding="                             "
  echo "${description}: ${padding:${#description}}${value}"
}

kctl_show_version.show_complex_value() {
  local description="${1}" current_value="${2}" applied_value="${3}"
  if [[ "${current_value}" == "${applied_value}" ]]; then
    kctl_show_version.show_value "${description}" "${current_value}"
  else
    kctl_show_version.show_value "${description}" "${applied_value} -> ${current_value}"
  fi
}

kctl_show_version.get_pretty_os_name() {
  env_files.read_var "/etc/os-release" "pretty_name"
}

kctl_show_version.detect_selinux_status() {
  if [ -x "$(command -v sestatus)" ]; then
    if sestatus | grep -q "SELinux status:" | awk '{ print $NF}'| grep -i 'enabled'; then
      echo -e "\e[31menabled ( Need to reboot )\e[0m"
    else
      echo "disabled"
    fi
  else
    echo "not supported"
  fi
}

kctl.get_user_id() {
  local user_name="${1}"
  get_user_id "${user_name}"
}

on_exit(){
  exit 1
}

kctl_certificates() {
  local action="${1:-}"
  shift || true
  case "${action}" in
    issue)
      kctl_certificates.issue "${@}"
      ;;
    revoke)
      kctl_certificates.revoke "${@}"
      ;;
    prune)
      kctl_certificates.prune "${@}"
      ;;
    renew)
      kctl_certificates.renew
      ;;
    remove-old-logs)
      kctl_certificates.remove_old_logs
      ;;
    fix-x3-expiration)
      kctl_certificates.fix_x3_expiration
      ;;
    fix-le-accounts)
      LOG_PATH="${LOG_DIR}/kctl-certificates-fix-le-accounts.log" kctl_certificates.fix_le_accounts
      ;;
    maintain)
      kctl_certificates.prune "safe"
      kctl_certificates.renew
      kctl_certificates.remove_old_logs
      ;;
    *)
      kctl_certificates.usage
  esac
}

KEITARO_SUPPORT_ACCESS_PERIOD_IN_DAYS='5'
KEITARO_SUPPORT_PUBLIC_KEY_URL="https://files.keitaro.io/keitaro/files/keitaro-support-public-key"
PATH_TO_KEITARO_SUPPORT_SSH_DIR="${KEITARO_SUPPORT_HOME_DIR}/.ssh"
PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS="${PATH_TO_KEITARO_SUPPORT_SSH_DIR}/authorized_keys"

kctl.support_team_access() {
  local action="${1}"
  case "${action}" in
    allow)
      kctl.support_team_access.allow
      ;;
    deny)
      kctl.support_team_access.deny
      ;;
    prune)
      kctl.support_team_access.prune
      ;;
    status)
      kctl.support_team_access.status
      ;;
    *)
      kctl.support_team_access.usage
      ;;
  esac
}

kctl.tracker_options.enable() {
  local tracker_option="${1}"
  if empty "${tracker_option}"; then
    kctl.tracker_options.help
  else
    if [[ "${tracker_option}" == 'rbooster' ]]; then
      kctl.use_clickhouse_olapdb
    else
      kctl.tracker_options.enable_tracker_option "${tracker_option}"
    fi
  fi
}

kctl.tracker_options.enable_tracker_option() {
  local tracker_option="${1}" tracker_options_arr
  # shellcheck disable=SC2207
  tracker_options_arr=( $(kctl.tracker_options.read) )
  if ! arrays.in "${tracker_option}" "${tracker_options_arr[@]}"; then
    tracker_options_arr+=( "${tracker_option}" )
    kctl.tracker_options.save "${tracker_options_arr[@]}"
  fi
  tracker.reconfigure
}

kctl.tracker_options.help() {
  echo "Usage:"
  echo "  kctl tracker-options enable <tracker_option>                  enable tracker_option"
  echo "  kctl tracker-options disable <tracker_option>                 disable tracker_option"
  echo "  kctl tracker-options help                                     print this help"
  echo
}

kctl.tracker_options.read() {
  local tracker_options
  tracker_options="$(inventory.read_var 'tracker_options')"
  echo "${tracker_options//,/ }"
}


kctl.tracker_options.disable() {
  local tracker_option="${1}"
  if empty "${tracker_option}"; then
    kctl.tracker_options.usage
  else
    if [[ "${tracker_option}" == "${TRACKER_OPTION_RBOOSTER}" ]]; then
      fail "This operation is not supported"
    else
      kctl.tracker_options.disable_tracker_option "${tracker_option}"
    fi
  fi
}

kctl.tracker_options.disable_tracker_option() {
  local tracker_option="${1}"
  local tracker_options_arr
  # shellcheck disable=SC2207
  tracker_options_arr=( $(kctl.tracker_options.read) )
  if arrays.in "${tracker_option}" "${tracker_options_arr[@]}"; then
    # shellcheck disable=SC2207
    tracker_options_arr=( $(arrays.remove "${tracker_option}" "${tracker_options_arr[@]}") )
    kctl.tracker_options.save "${tracker_options_arr[@]}"
  fi
  tracker.reconfigure
}

kctl.tracker_options.save() {
  local tracker_options="${1}"
  inventory.save_var 'tracker_options' "${tracker_options// /,}"
}


kctl_podman() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    start)
      kctl_podman.start "${1}"
      ;;
    stop)
      kctl_podman.stop "${1}"
      ;;
    prune)
      kctl_podman.prune "${1}"
      ;;
    stats)
      kctl_podman.stats
      ;;
    help)
      kctl_podman.usage
      ;;
    *)
      kctl_podman.usage
      exit 1
      ;;
  esac
}

kctl_certificates.revoke() {
  local domains="${*}"
  "${KCTL_BIN_DIR}/kctl-disable-ssl" -D "${domains// /,}"
}

kctl_certificates.prune() {
  "${KCTL_BIN_DIR}/kctl-certificates-prune" "${@}"
}

LETSENCRYPT_ACCOUNTS_PATH="${LETSENCRYPT_DIR}/accounts/acme-v02.api.letsencrypt.org/directory/"

kctl_certificates.fix_le_accounts() {
  local accounts_count

  if [[ ! -d "${LETSENCRYPT_ACCOUNTS_PATH}" ]]; then
    certbot.register_account
  fi

  accounts_count="$(kctl_certificates.count_account)"

  if [[ "${accounts_count}" == '0' ]]; then
    certbot.register_account
  fi

  if [[ "${accounts_count}" -gt '1' ]]; then
    kctl_certificates.remove_redundant_accounts
  fi

  kctl_certificates.fix_account_in_renewal_configs
}

kctl_certificates.count_account() {
 find "${LETSENCRYPT_ACCOUNTS_PATH}" -maxdepth 1 -mindepth 1 -type d | wc -l
}

kctl_certificates.remove_redundant_accounts() {
  local sorted_accounts accounts_to_remove

  # shellcheck disable=SC2207
  sorted_accounts=( $(/usr/bin/ls -t "${LETSENCRYPT_ACCOUNTS_PATH}") )

  accounts_to_remove=( "${sorted_accounts[@]:1}" )
  debug "Removing ${#accounts_to_remove[@]} accounts: ${accounts_to_remove[*]}"

  for account in "${accounts_to_remove[@]}"; do
    rm -rf "${LETSENCRYPT_ACCOUNTS_PATH}/${account:?}"
  done

}

kctl_certificates.fix_account_in_renewal_configs() {
  local account

  account="$(/usr/bin/ls -t "${LETSENCRYPT_ACCOUNTS_PATH}" | head -n 1)"

  if [[ -d "${LETSENCRYPT_DIR}/renewal/" ]]; then
    cmd="(grep -R -L 'account = ${account}' ${LETSENCRYPT_DIR}/renewal/ || true)"
    cmd="${cmd} | xargs --max-args=100 --no-run-if-empty sed 's/account = .*/account = ${account}/' -i"
    run_command "${cmd}" " Fix renewal configs"
  fi
}

kctl_certificates.remove_old_logs() {
  /usr/bin/find /var/log/keitaro/ssl -mtime +30 -type f -delete
  /usr/bin/find /var/log/letsencrypt-renew -mtime +30 -type f -delete
  /usr/bin/find /var/log/letsencrypt -mtime +30 -type f -delete
}

kctl_certificates.renew() {
  local success_flag_filepath="/var/lib/letsencrypt-renew/.renewed"
  local message="Renewing LE certificates"
  local log_path="${LOG_DIR}/kctl-renew-certificates.log"
  local cmd

  LOG_PATH="${log_path}"
  init_log "${log_path}"

  debug "Renewing certificates"

  cmd="rm -f '${success_flag_filepath}'"
  cmd="${cmd} && $(kctl_certificates.build_renew_cmd)"

  run_command "${cmd}" "${message}" 'hide_output' 'allow_errors' || \
    debug "Errors occurred while renewing some certificates. certbot exit code: ${?}"

  if file_exists "${success_flag_filepath}"; then
    debug "Some certificates have been renewed. Removing flag file ${success_flag_filepath} and reloading nginx"
    cmd="rm -f '${success_flag_filepath}' && systemctl reload nginx"
    run_command "${cmd}" "Reloading nginx" 'hide_output'
  else
    debug "Certificates have not been updated."
  fi
}

kctl_certificates.build_renew_cmd() {
  echo "LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run certbot renew" \
        "--allow-subset-of-names" \
        "--no-random-sleep-on-renew" \
        "--renew-hook 'touch ${success_flag_filepath}'" \
        "--work-dir /var/lib/letsencrypt-renew" \
        "--logs-dir /var/log/letsencrypt-renew"
}

kctl_certificates.usage() {
  echo "Usage:"
  echo "  kctl certificates issue DOMAIN1[ DOMAIN2][...]          issue LE certificates for the specified domains"
  echo "  kctl certificates revoke DOMAIN1[ DOMAIN2][...]         revoke LE certificates for the specified domains"
  echo "  kctl certificates renew                                 renew LE certificates"
  echo "  kctl certificates remove-old-logs                       remove old issuing logs"
  LOG_PATH=/dev/null "${KCTL_BIN_DIR}/kctl-certificates-prune" help
  echo "  kctl certificates maintain                              safe prune certifictes, renew and remove old issuing logs"
  echo
}

PEM_SPLITTER="-----BEGIN CERTIFICATE-----"

kctl_certificates.fix_x3_expiration() {
  local live_certificate_filepaths
  local temporary_dir
  local certificate_chain_without_x3
  live_certificate_filepaths=$(get_live_certificate_filepaths)
  for certificate_path in $live_certificate_filepaths; do
    if is_last_certificate_issued_by_x3 "${certificate_path}"; then
      debug "Certificate chain ${certificate_path} contains a certificate from X3, removing X3 from the chain"
      backup_certificate "${certificate_path}"
      remove_last_certificate_from_chain "${certificate_path}"
    else
      debug "Certificate chain ${certificate_path} does not contain a certificate from X3, wont modify the chain"
    fi
  done
}


get_live_certificate_filepaths(){
  if [[ -d /etc/letsencrypt/live/ ]]; then
    find /etc/letsencrypt/live/ -name fullchain.pem -print0 | xargs -0 --no-run-if-empty readlink -f
  fi
}


backup_certificate(){
  local certificate_path="${1}"
  local domain_name
  local backup_directory
  domain_name=$(basename "$(dirname "${certificate_path}")")
  backup_directory="/etc/keitaro/backups/letsencrypt/${CURRENT_DATETIME}/${domain_name}"

  mkdir -p "${backup_directory}" && /bin/cp -f "${certificate_path}" "${backup_directory}"
  debug "Certificates chain for ${domain_name} was saved to ${backup_directory}"
}


is_last_certificate_issued_by_x3() {
  local certificate_path="${1}"
  local chain_content
  chain_content="$(< "${certificate_path}")"
  local last_certificate_content="${PEM_SPLITTER}${chain_content##*"${PEM_SPLITTER}"}"
  echo "$last_certificate_content" | openssl x509 -text | grep 'Issuer' | grep 'DST Root CA X3' -q
}


remove_last_certificate_from_chain() {
  local certificate_path="${1}"
  local certificate_chain_content
  certificate_chain_content="$(< "${certificate_path}")"
  local certificate_chain_wo_x3_content="${certificate_chain_content%"${PEM_SPLITTER}"*}"
  echo "${certificate_chain_wo_x3_content}" > "${certificate_path}"
}

kctl_certificates.issue() {
  FORCE_ISSUING_CERTS=true "${KCTL_BIN_DIR}/kctl-enable-ssl" "${@}"
}

kctl.use_clickhouse_olapdb.set_olap_db() {
  local olap_db="${1}"

  inventory.save_var 'olap_db' "${olap_db}"

  tracker.reconfigure
}

kctl.use_clickhouse_olapdb.run_ch_converter(){
  local options
  options="--env-file-path=${PATH_TO_COMPONENTS_ENV}"
  options="${options} --prefix='$(inventory.read_var 'tracker_tables_prefix')'"
  options="${options} --ms-host='$(components.read_var 'mariadb' 'host')'"
  options="${options} --ms-db='$(inventory.read_var 'mariadb_keitaro_database')'"
  options="${options} --ms-user='$(inventory.read_var 'mariadb_keitaro_user')'"
  options="${options} --ms-password='$(inventory.read_var 'mariadb_keitaro_password')'"
  options="${options} --ch-host='$(components.read_var 'clickhouse' 'host')'"
  options="${options} --ch-db='$(inventory.read_var 'clickhouse_keitaro_database')'"
  options="${options} --ch-user='$(inventory.read_var 'clickhouse_keitaro_user')'"
  options="${options} --ch-password='$(inventory.read_var 'clickhouse_keitaro_password')'"
  run_command "TZ=UTC ${KCTL_BIN_DIR}/kctl-ch-converter ${options}"
}

kctl.use_clickhouse_olapdb.switch_olapdb_to_clickhouse() {
  local olap_db applied_olap_db
  olap_db="$(inventory.read_var 'olap_db')"
  applied_olap_db="$(env_files.read_applied_var 'olap_db')"

  if [[ "${olap_db}" != 'clickhouse'  ]] || [[ "${applied_olap_db}" != 'clickhouse' ]]; then
    kctl.use_clickhouse_olapdb.set_olap_db "${OLAP_DB_CLICKHOUSE}"
  fi

  kctl.use_clickhouse_olapdb.run_ch_converter

  env_files.save_applied_var 'olap_db' "${olap_db}"
}

kctl.normalize() {
  tracker.stop_running_tracker_tasks
  kctl.use_clickhouse_olapdb.switch_olapdb_to_clickhouse
  tracker.start_running_tracker_tasks
}

kctl.support_team_access.prune() {
  local mtime
  mtime="$(( KEITARO_SUPPORT_ACCESS_PERIOD_IN_DAYS - 1 ))"
  if [[ -f "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}" ]]; then
    find "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}" -mtime "+${mtime}" -delete
    if [[ ! -f "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}" ]]; then
      echo "Pruned expired authorized_keys of the ${KEITARO_SUPPORT_USER} user"
    fi
  fi
}


kctl.support_team_access.status() {
  if [[ -f "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}" ]]; then
    echo "Keitaro Support Team access to this server will expire at $(kctl.support_team_access.get_expire_time)"
  else
    echo "Keitaro Support Team has no access to this server"
  fi
}

kctl.support_team_access.get_keys_creation_time() {
  date -u -r "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"
}

kctl.support_team_access.get_expire_time() {
  local keys_creation_time

  keys_creation_time="$(kctl.support_team_access.get_keys_creation_time)"
  date -u -d "${keys_creation_time} + ${KEITARO_SUPPORT_ACCESS_PERIOD_IN_DAYS} days"
}

kctl.support_team_access.usage() {
  echo "Usage:"
  echo "  kctl support-team-access allow                        allows Keitaro Support Team access to the server"
  echo "  kctl support-team-access deny                         denies Keitaro Support Team access to the server"
  echo "  kctl support-team-access prune                        prunes expired Keitaro Support Team access keys"
  echo "  kctl support-team-access status                       shows Keitaro Support Team access to the server status"
  echo "  kctl support-team-access usage                        prints this page"
}

kctl.support_team_access.deny() {
  rm -f "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"

  kctl.support_team_access.status
}

kctl.support_team_access.allow() {
  local expiration_datetime pub_key_tpl_url path_to_pub_key_tpl

  kctl.support_team_access.create_ssh_authorized_keys

  cache.download "${KEITARO_SUPPORT_PUBLIC_KEY_URL}"
  path_to_pub_key="$(cache.path_by_url "${KEITARO_SUPPORT_PUBLIC_KEY_URL}")"

  cat "${path_to_pub_key}" > "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"

  kctl.support_team_access.status
}


kctl.support_team_access.create_ssh_authorized_keys() {
  if [[ ! -d "${PATH_TO_KEITARO_SUPPORT_SSH_DIR}" ]]; then
    mkdir -p "${PATH_TO_KEITARO_SUPPORT_SSH_DIR}"
    chmod 0700 "${PATH_TO_KEITARO_SUPPORT_SSH_DIR}"
    chown "${KEITARO_SUPPORT_USER}:${KEITARO_SUPPORT_USER}" "${PATH_TO_KEITARO_SUPPORT_SSH_DIR}"
  fi
  if [[ ! -f "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}" ]]; then
    touch "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"
    chmod 0600 "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"
    chown "${KEITARO_SUPPORT_USER}:${KEITARO_SUPPORT_USER}" "${PATH_TO_KEITARO_SUPPORT_SSH_AUTHORIZED_KEYS}"
  fi
}

DNS_GOOGLE="8.8.8.8"
RESOLV_CONF_PATH="${ROOT_PREFIX}/etc/resolv.conf"

kctl_resolvers() {
  local action="${1}"
  case "${action}" in
    set-google)
      kctl_resolvers_set_google
      ;;
    reset)
      kctl_resolvers_reset
      ;;
    autofix)
      kctl_resolvers_autofix
      ;;
    *)
      kctl_resolvers_usage
  esac
}

kctl_resolvers_usage() {
  echo "Usage:"
  echo "  kctl resolvers autofix                           sets google dns if current resolver works slow"
  echo "  kctl resolvers set-google                        sets google dns"
  echo "  kctl resolvers reset                             resets settings"
  echo "  kctl resolvers usage                             prints this page"
}

kctl_resolvers_autofix() {
  if resolver_works_slow; then
    echo "DNS resolver works too slow, switching to Google DNS"
    kctl_resolvers_set_google
  fi
}

resolver_works_slow() {
  local first_ipv4_dns_server
  first_ipv4_dns_server=$(grep -Pom1 "(?<=^nameserver )\d+(\.\d+){3}$" "${RESOLV_CONF_PATH}")
  if nslookup -timeout=1 -retry=0 keitaro.io "${first_ipv4_dns_server}" &>/dev/null; then
    return ${FAILURE_RESULT}
  else
    return ${SUCCESS_RESULT}
  fi
}

kctl_resolvers_reset() {
  local resolvers_entry="nameserver ${DNS_GOOGLE}"
  if file_content_matches "${RESOLV_CONF_PATH}" '-F' "${resolvers_entry}"; then
    other_ipv4_entries=$(grep "^nameserver" "${RESOLV_CONF_PATH}" | grep -vF "${resolvers_entry}" | grep '\.')
    debug "Other ipv4 entries: ${other_ipv4_entries}"
    if isset "${other_ipv4_entries}"; then
      debug "${RESOLV_CONF_PATH} contains 'nameserver ${DNS_GOOGLE}', deleting"
      run_command "sed -r -i '/^nameserver ${DNS_GOOGLE}$/d' '${RESOLV_CONF_PATH}'"
    else
      debug "${RESOLV_CONF_PATH} contains only one ipv4 nameserver keeping"
    fi
  else
    debug "${RESOLV_CONF_PATH} doesn't contain 'nameserver ${DNS_GOOGLE}', skipping"
  fi
}

kctl_resolvers_set_google() {
  if file_content_matches "${RESOLV_CONF_PATH}" '-F' "nameserver ${DNS_GOOGLE}"; then
    debug "${RESOLV_CONF_PATH} already contains 'nameserver ${DNS_GOOGLE}', skipping"
  else
    debug "${RESOLV_CONF_PATH} doesn't contain 'nameserver ${DNS_GOOGLE}', adding"
    run_command "sed -i '1inameserver ${DNS_GOOGLE}' ${RESOLV_CONF_PATH}"
  fi
}

kctl.use_clickhouse_olapdb() {
  tracker.stop_running_tracker_tasks
  kctl.use_clickhouse_olapdb.switch_olapdb_to_clickhouse
  tracker.start_running_tracker_tasks
}

kctl_check() {
  local has_inactive=0

  for component in $(components.list_origin | grep -v nginx-starting-page); do
    for service in $(components.read_var "${component}" "services"); do
      printf 'Checking service %s .' "${service}"
      if systemctl -q is-active "$service"; then
        echo " OK"
      else
        echo " NOK"
        echo "Service ${service} is inactive" >&2
        has_inactive=1
      fi
    done
  done
  if [[ ${has_inactive} != 1 ]]; then
    echo "Everything is ok"
  fi
  return $has_inactive
}

kctl_run() {
  local action="${1:-}"
  shift || true

  case "${action}" in
      ?(system-)+(clickhouse|mariadb|mysql|redis)-+(client|query) )
      kctl_run.podman_action "${action}" "${@}"
      ;;
    cli-php | php-cli)
      chroot --userspec=keitaro / bash -c "cd '${TRACKER_ROOT}' && /usr/bin/kctl-php ./bin/cli.php ${*}"
      ;;
    nginx)
      kctl_run.run_podman_exec 'nginx' "${@}"
      ;;
    certbot | certbot-renew)
      if [[ "${#}" -gt 0 ]]; then
        set -- "${@}" --max-log-backups=10
      fi
      kctl_podman.run 'certbot' "${@}"
      ;;
    help)
      kctl_run_usage
      ;;
    *)
      kctl_run_usage
      exit 1
      ;;
  esac
}

kctl.tracker_options() {
  local action="${1}"
  local tracker_option="${2}"
  case "${action}" in
    enable)
      kctl.tracker_options.enable "${tracker_option}"
      ;;
    disable)
      kctl.tracker_options.disable "${tracker_option}"
      ;;
    help)
      kctl.tracker_options.help
      ;;
    *)
      kctl.tracker_options.help
      exit 1
      ;;
  esac
}

kctl_run.run_client() {
  local component="${1}" database="${2}"
  local podman_exec_cmd; podman_exec_cmd="$(kctl_run.build_podman_exec '-it' "${component}" "${database}")"

  debug "Evaluating \`${podman_exec_cmd}\`"
  ${podman_exec_cmd}
}

kctl_run_usage(){
  echo "Usage:"
  echo "  kctl run clickhouse-client                  run clickhouse keitaro db shell"
  echo "  kctl run clickhouse-query                   execute clickhouse keitaro db query"
  echo "  kctl run mariadb-client                     run mariadb keitaro db shell"
  echo "  kctl run mariadb-query                      execute mariadb keitaro db query"
  echo "  kctl run redis-client                       run redis keitaro db shell"
  echo "  kctl run redis-query                        execute redis keitaro db query"
  echo "  kctl run system-clickhouse-client           run clickhouse system db shell"
  echo "  kctl run system-clickhouse-query            execute clickhouse system db query"
  echo "  kctl run system-mariadb-client              run mariadb system db shell"
  echo "  kctl run system-mariadb-query               execute mariadb system db query"
  echo "  kctl run system-redis-client                run redis system db shell"
  echo "  kctl run system-redis-query                 execute redis system db query"
  echo "  kctl run cli-php <command>                  execute cli.php command"
  echo "  kctl run nginx <command>                    perform nginx command"
  echo "  kctl run certbot                            perform certbot command"
}

kctl_run.execute_query() {
  local component="${1}" database="${2}" query="${3:-}"
  local podman_exec_cmd query_option

  podman_exec_cmd="$(kctl_run.build_podman_exec '-i' "${component}" "${database}")"
  podman_exec_cmd="${podman_exec_cmd} $(components.read_var "${component}" 'client_command_options_query_defaults')"

  if [[ "${query}" == "" ]]; then
    debug "Evaluating ${component} query. Assume query is passed via stdin. Command: \`${podman_exec_cmd}\`"
    ${podman_exec_cmd}
  else
    query_option="$(components.read_var "${component}" 'client_command_option_query')"
    if [[ "${query_option}" != "" ]]; then
      debug "Evaluating query. Pass query via args. Command: \`${podman_exec_cmd} ${query_option}\"${query}\"\`"
      ${podman_exec_cmd} "${query_option}""${query}"
    else
      debug "Evaluating ${component} query. Pass query via stdin. Command: \`echo \"${query}\" | ${podman_exec_cmd}\`"
      echo "${query}" | ${podman_exec_cmd}
    fi
  fi
}

kctl_run.run_podman_exec() {
  local component="${1}"; shift

  cmd="$(kctl_run.build_podman_exec '-i' "${component}" "") ${*}"

  debug "Evaluating \`${cmd}\`"
  ${cmd}
}

kctl_run.podman_action() {
  local action="${1}"; shift

  case "${action}" in
    system-redis* )
      database='keitaro'
      component='system-redis'
      ;;
    system* )
      database='system'
      action="${action:7}"        # remove `system-` prefix
      component="${action%%-*}"   # get first chars before `-`
      ;;
    *)
      database='keitaro'
      component="${action%%-*}"   # get first chars before `-`
      ;;
  esac

  if [[ "${component}" == 'mysql' ]]; then
    component="mariadb"
  fi

  if [[ "${action}" =~ query$ ]]; then
    kctl_run.execute_query "${component}" "${database}" "${@}"
  else
    kctl_run.run_client "${component}" "${database}"
  fi
}

####
#
# kctl_run.build_podman_exec:   Builds podman exec to run the command in the component's environment
#
# Arguments:
#   podman_exec_options:        Options to pass to `podman exec`. Usually its one of `-i` or `-it`
#   component:                  Component within which the client command is executed. E.g. `clickhouse`, `mariadb`, `redis`
#   database:                   Working database. Valid values: ``, `keitaro`, `root`.
#
kctl_run.build_podman_exec() {
  local podman_exec_options="${1}" component="${2}" database="${3}" cmd

  components.assert_var_is_set "${component}" 'client_command'
  cmd="$(components.read_var "${component}" 'client_command')"

  local cmd_options; cmd_options="$(kctl_run_client.build_podman_exec.build_cmd_options "${component}" "${database}")"

  echo "podman exec --env HOME=/tmp ${podman_exec_options} ${component} ${cmd} ${cmd_options}"
}

kctl_run_client.build_podman_exec.build_cmd_options() {
  local component="${1}" database="${2}" cmd_options var_name value

  for var_name in host port; do
    value="$(components.read_var "${component}" "${var_name}")"
    cmd_options="${cmd_options} $(kctl_run_client.build_podman_exec.build_cmd_option "${component}" "${var_name}" "${value}")"
  done

  if [[ "${database}" != "" ]]; then
    for var_name in user password database; do
      value="$(inventory.read_var "${component}_${database}_${var_name}")"
      cmd_options="${cmd_options} $(kctl_run_client.build_podman_exec.build_cmd_option "${component}" "${var_name}" "${value}")"
    done
  fi

  echo "${cmd_options}"
}

kctl_run_client.build_podman_exec.build_cmd_option() {
  local component="${1}" var_name="${2}" value="${3}" cmd_option

  if [[ "${value}" != "" ]]; then
    cmd_option="$(components.read_var "${component}" "client_command_option_${var_name}")"
    if [[ "${cmd_option}" != "" ]]; then
      echo "${cmd_option}${value}"
    fi
  fi
}

PATHS_TO_CONTAINERS_JSON=(
  "/var/lib/containers/storage/overlay-containers/containers.json"
  "/var/lib/containers/storage/overlay-containers/volatile-containers.json"
)

kctl_podman.prune() {
  local component="${1}"
  local container_name; container_name="$(kctl_podman.get_container_name "${component}")"
  kctl_podman.prune.safely_stop_container "${container_name}"
  kctl_podman.prune.safely_remove_container "${container_name}"
  kctl_podman.prune.safely_remove_container_storage "${container_name}"
  kctl_podman.prune.safely_remove_container "${container_name}"
  kctl_podman.prune.safely_remove_container_storage "${container_name}"
  kctl_podman.prune.safely_remove_container_from_json "${container_name}"
  kctl_podman.prune.safely_remove_container "${container_name}"
}


kctl_podman.prune.safely_stop_container() {
  local container="${1}"

  if podman ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
    kctl_podman.prune.stop_container "${container}" || true
  fi
}

kctl_podman.prune.stop_container() {
  local container="${1}"

  echo "Stopping container ${container}: \`podman stop ${container}\`"
  podman stop "${container}"
}

kctl_podman.prune.safely_remove_container_storage() {
  local container="${1}"
  for path_to_containers_json in "${PATHS_TO_CONTAINERS_JSON[@]}"; do
    if kctl_podman.prune.container_has_storage "${container}" "${path_to_containers_json}"; then
      kctl_podman.prune.remove_container_storage "${container}" || true
    fi
  done
}

kctl_podman.prune.remove_container_storage() {
  local container="${1}"

  echo "Removing ${container} container's storage: \`podman rm --force --storage ${container}\`"
  podman rm --force --storage "${container}"
}

kctl_podman.prune.safely_remove_container() {
  local container="${1}"

  if podman ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
    kctl_podman.prune.remove_container "${container}" || true
  fi
}

kctl_podman.prune.remove_container() {
  local container="${1}"

  echo "Removing running ${container} container: \`podman rm --force ${container}\`"
  podman rm --force "${container}"
}

kctl_podman.prune.safely_remove_container_from_json() {
  local container="${1}"

  for path_to_containers_json in "${PATHS_TO_CONTAINERS_JSON[@]}"; do
    if kctl_podman.prune.container_has_storage "${container}" "${path_to_containers_json}"; then
      kctl_podman.prune.remove_container_from_json "${container}" "${path_to_containers_json}" || true
    fi
  done
}

kctl_podman.prune.remove_container_from_json() {
  local container="${1}" path_to_containers_json="${2}"
  local jq_query="del(.[] | select(.names[] == \"${container}\"))"

  cmd="jq -Mre '${jq_query}' ${path_to_containers_json} > ${path_to_containers_json}.new"
  cmd="${cmd} && mv ${path_to_containers_json}.new ${path_to_containers_json}"

  echo "Removing container from json: \`${cmd}\`"
  jq -Mre "${jq_query}" "${path_to_containers_json}" > "${path_to_containers_json}.new" \
    && mv "${path_to_containers_json}.new" "${path_to_containers_json}"
}

kctl_podman.prune.container_has_storage() {
  local container="${1}" path_to_containers_json="${2}"
  local jq_query="[ .[] | select( .names[] == \"${container}\") ] | .[0]"

  [[ -f "${path_to_containers_json}" ]] && jq -Mre "${jq_query}" "${path_to_containers_json}" > /dev/null
}

kctl_podman.start() {
  local component="${1}"

  local container_name; container_name="$(kctl_podman.get_container_name "${component}")"

  kctl_podman.assert_component_is_supported "${component}"
  kctl_podman.prune "${component}"
  kctl_podman.start_service "${component}" "${container_name}"
}

kctl_podman.start_service() {
  local component="${1}" container_name="${2}"
  local podman_args; podman_args="$(kctl_podman.build_args "${component}")"

  components.run "${component}" "${container_name}" "${podman_args}"
}

kctl_podman.usage(){
  local all_components
  # shellcheck disable=SC2207
  all_components=( $(components.list_origin) )
  echo "Usage:"
  echo "  kctl podman start COMPONENT                   starts COMPONENT's container (it stops and prunes COMPONENT before)"
  echo "  kctl podman stop  COMPONENT                   stops COMPONENT's container"
  echo "  kctl podman prune COMPONENT                   removes COMPONENT's container and storage assotiated with it"
  echo "  kctl podman stats                             prints statistics"
  echo "  kctl podman usage                             prints this info"
  echo
  echo "Allowed COMPONENTs are: ${all_components[*]}"
}

kctl_podman.get_container_name() {
  local component="${1}" cmd="${2:-}" name

  if [[ "${CONTAINER_NAME:-}" != "" ]]; then
    echo "${CONTAINER_NAME}"
    return
  fi

  name="${component}"
  if [[ "${cmd}" != "" ]]; then
    name="${name}-${cmd}"
  fi

  for var in $(components.read_var "${component}" 'runtime_vars'); do
    if [[ "${!var:-}" != "" ]]; then
      name="${name}-${var}-${!var}"
    fi 
  done

  components.normalize_name "${name}"
}

kctl_podman.stop() {
  local component="${1}"
  local container_name; container_name="$(kctl_podman.get_container_name "${component}")"

  echo "Stopping ${container_name} container"
  podman stop "${container_name}"

  kctl_podman.prune "${component}"
}

kctl_podman.assert_component_is_supported() {
  local component="${1}"
  local nl=$'\n'
  local all_components

  # shellcheck disable=SC2207
  all_components=( $(components.list_origin) )

  if ! arrays.in "${component}" "${all_components[@]}"; then
    kctl_podman.usage
    exit 1
  fi
}


kctl_podman.stats() {
  podman stats --no-stream --format json
}

kctl_podman.run() {
  local component="${1}"; shift 1

  kctl_podman.assert_component_is_supported "${component}"
  kctl_podman.prune "${component}"

  podman_args="$(kctl_podman.build_args "${component}")"

  local container_name; container_name="$(kctl_podman.get_container_name "${component}" "${@}")"
  components.run "${component}" "${container_name}" "${podman_args}" "${@}"
}

kctl_podman.build_args() {
  local component="${1}"
  local podman_args

  podman_args="${podman_args} $(kctl_podman.build_args.user_and_group "${component}")"

  podman_args="${podman_args} $(kctl_podman.build_args.env_vars "${component}" 'runtime_vars')"
  podman_args="${podman_args} $(kctl_podman.build_args.env_vars "${component}" 'private_vars')"
  podman_args="${podman_args} $(kctl_podman.build_args.env_vars "${component}" 'shared_vars')"
  for a_component in $(components.read_var "${component}" "depends_on"); do
    podman_args="${podman_args} $(kctl_podman.build_args.env_vars "${a_component}" 'shared_vars')"
  done

  echo "${podman_args}"
}

kctl_podman.build_args.user_and_group() {
  local component="${1}" root_mode user_id group_id

  root_mode="$(components.read_var "${component}" "service_run_as_root")"
  user_id=$(components.detect_user_id "${component}")
  group_id=$(components.detect_group_id "${component}")

  if [[ "${root_mode}" == "" ]]; then
    echo "--user ${user_id}:${group_id}"
  else
    local component_var; component_var="$(env_files.normalize_var_name "${component}")"
    echo "--env ${component_var}_USER_UID=${user_id} --env ${component_var}_USER_GID=${group_id}"
  fi
}

kctl_podman.build_args.env_vars() {
  local component="${1}" vars_source="${2}" args arg

  for var in $(components.read_var "${component}" "${vars_source}"); do
    local arg; arg="$(kctl_podman.build_args.env_vars.build_arg "${component}" "${var}")"
    if [[ "${arg}" != "" ]]; then
      args="${args} ${arg}"
    fi
  done

  echo "${args}"
}

kctl_podman.build_args.env_vars.build_arg() {
  local component="${1}" var="${2}" unprefixed_var value

  unprefixed_var="$(kctl_podman.build_args.unprefix_component_var "${component}" "${var}")"
  if components.has_var "${component}" "${unprefixed_var}"; then
    value="$(components.read_var "${component}" "${unprefixed_var}")"
  elif inventory.has_var "${var}"; then
    value="$(inventory.read_var "${var}")"
  elif [[ ${!var:-} != "" ]]; then
    local unsanitized_value="${!var}"
    value="${unsanitized_value//[^[:alnum:]]/}"
  else
    return
  fi

  echo "--env ${var}=${value}"
}

kctl_podman.build_args.unprefix_component_var() {
  local component="${1}" raw_var_name="${2}"
  local var_name; var_name="$(env_files.normalize_var_name "${raw_var_name}")"
  local component_var; component_var="$(env_files.normalize_var_name "${component}")"

  if [[ "${var_name}" =~ ^${component_var}_ ]]; then
    local component_var_prefix_length="${#component_var}"
    local unneeded_prefix_length="$((component_var_prefix_length + 1))"
    echo "${var_name:${unneeded_prefix_length}}"
  else
    echo "${var_name}"
  fi
}

kctl.reset.db_component() {
  local component="${1}"

  for user in keitaro system; do
    kctl.reset.inventory_item "${component}_${user}_password"
  done

  components.with_services_do "${component}" 'restart'
  components.wait_until_is_up "${component}"
}

kctl.reset.tracker() {
  kctl.reset.inventory_item 'tracker_salt'
  kctl.reset.tracker.server_ip
  tracker.generate_artefacts
  run_command "LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run cli-php ch_db:recreate_foreign_tables" "Fixing CH" 'hide_output'
  tracker.reconfigure
}

kctl.reset.tracker.server_ip() {
  local server_ip
  if ! server_ip="$(gathering.gather_server_ip)"; then
    fail "$(translate 'errors.cant_detect_server_ip')"
  fi
  inventory.save_var "server_ip" "${server_ip}"
}

kctl.reset.machine_id() {
  generate_16hex > /etc/machine-id
  systemd.restart_service 'systemd-journald'
}

kctl.reset.inventory_item() {
  local item="${1}"
  local value; value="$(generate_16hex)"

  inventory.save_var "${item}" "${value}"
}
CURRENT_DATETIME="$(date +%Y%m%d%H%M)"
SKIP_START_CERTIFICATES_RENEWAL="${SKIP_START_CERTIFICATES_RENEWAL:-}"
declare -a RETRY_INTERVALS=(60 180 300)
declare -A DICT
DICT['en.messages.sleeping_before_next_try']="Error while install, sleeping for :retry_interval: seconds before next try"
DICT['en.messages.kctl_version']="Kctl:    :kctl_version:"
DICT['en.messages.kctl_tracker']="Tracker: :tracker_version:"
DICT['en.errors.invalid_options']="Invalid option ${1}. Try 'kctl help' for more information."
DICT['en.errors.tracker_is_not_installed']="Keitaro tracker is not installed"

TRACKER_CONFIG_INI_PHP_PATH="application/config/config.ini.php"
TRACKER_STATS_JSON_PATH="var/stats.json"

tracker.generate_artefacts() {
  if is_ci_mode; then
    debug "CI mode detected - skip generating tracker's artefacts"
    return
  else
    debug "Generating tracker's artefacts"
  fi

  local tracker_root; tracker_root="$(components.build_path_to_preinstalled_directory "${TRACKER_COMPONENT}")/www"
  local path_to_kctl; path_to_kctl="$(components.build_path_to_preinstalled_directory 'kctl')"

  tracker.generate_artefacts.generate_config_ini_php "${path_to_kctl}" "${tracker_root}"
  tracker.generate_artefacts.generate_stats_json "${path_to_kctl}" "${tracker_root}"

  for path in "${TRACKER_CONFIG_INI_PHP_PATH}" "${TRACKER_STATS_JSON_PATH}"; do
    if [[ -f "${TRACKER_ROOT}/${path}" ]]; then
      run_command "/bin/cp -f ${tracker_root}/${path} ${TRACKER_ROOT}/${path}" "Updating tracker's ${path}" 'hide_output'
    fi
  done
}

tracker.generate_artefacts.generate_config_ini_php() {
  local path_to_kctl="${1}"
  local tracker_root="${2}"
  local config_ini_path="${tracker_root}/${TRACKER_CONFIG_INI_PHP_PATH}"
  local cmd="set -o allexport"
  local user; user="$(components.read_var 'tracker' 'user')"
  local group; group="$(components.read_var 'tracker' 'group')"
  cmd="${cmd} && source ${PATH_TO_INVENTORY_ENV}"
  cmd="${cmd} && source ${PATH_TO_COMPONENTS_ENV}"
  for component in clickhouse kctld mariadb redis tracker; do
    cmd="${cmd} && source ${PATH_TO_ENV_DIR}/components/${component}.env"
  done
  cmd="${cmd} && envsubst < ${path_to_kctl}/files/etc/keitaro/config/config.ini.php.tpl > ${config_ini_path}"
  cmd="${cmd} && chown ${user}:${group} ${config_ini_path}"
  run_command "${cmd}" "Generating tracker's config" 'hide_output'
}

tracker.generate_artefacts.generate_stats_json() {
  local path_to_kctl="${1}"
  local tracker_root="${2}"
  local cmd="TRACKER_ROOT=${tracker_root} ${path_to_kctl}/bin/kctl-monitor"
  run_command "${cmd}" "Generating tracker's stats.json" 'hide_output'
}

tracker.reconfigure() {
  tracker.generate_artefacts
  systemd.restart_service 'php74-php-fpm'
  systemd.restart_service 'roadrunner'
  systemd.restart_service 'tracker-timers.target'
}

tracker.start_running_tracker_tasks() {
  systemd.start_service tracker-timers.target
}

TRACKER_CRON_WAIT_CYCLES=60
TRACKER_CRON_WAIT_PERIOD_IN_SEC=10

tracker.stop_running_tracker_tasks() {
  systemd.stop_service tracker-timers.target

  local pattern="cli-php"
  for ((i=0; i<TRACKER_CRON_WAIT_CYCLES; i++)); do
    if pgrep -f cli-php > /dev/null; then
      local msg
      msg="$((i+1))/${TRACKER_CRON_WAIT_CYCLES} Tracker's background tasks are still running."
      msg="${msg}. Wait ${TRACKER_CRON_WAIT_PERIOD_IN_SEC} seconds."
      echo "${msg}"
      sleep "${TRACKER_CRON_WAIT_PERIOD_IN_SEC}"
    else
      echo "All tracker background tasks are finished. Continue."
      break
    fi
  done
}
generate_16hex() {
  uuidgen | tr -d '-'
}

join_by(){
  local delimiter=$1
  shift
  echo -n "$1"
  shift
  printf "%s" "${@/#/${delimiter}}"
}

VOWELS="aeiou"

# From https://speakspeak.com/resources/english-grammar-rules/english-spelling-rules/double-consonant-ed-ing

strings.add_suffix() {
  local value="${1}" suffix="${2}"

  if stings.add_suffix.remove_last_char "${value}"; then
    echo "${value:0: -1}${suffix}"
    return
  fi
  if strings.add_suffix.dublicate_last_char "${value}"; then
    echo "${value}${value: -1}${suffix}"
  else
    echo "${value}${suffix}"
  fi
}

# We remove last e:
#   enable – enabling, enabled.
stings.add_suffix.remove_last_char() {
  local value="${1}"
  [[ "${value}" =~ e$ ]]
}

# We double the final letter when a one-syllable verb ends in consonant + vowel + consonant.
# stop, rob, sit 	stopping, stopped, robbing, robbed, sitting
#
# We double the final letter when a word has more than one syllable, and when the final syllable is stressed in speech.
# beGIN, preFER 	beginning, preferring, preferred
#
# We do not double the final letter if the final syllable is not stressed
# LISten, HAPpen 	listening, listened, happening, happened
#
# We duplicate last letter if word contains less then 3 syllables
strings.add_suffix.dublicate_last_char() {
  local value="${1}"

  ! stings.add_suffix.keep_last_char "${value}" \
    && [[ ! "${value}" =~ [${VOWELS}]+[^${VOWELS}]+[$VOWELS]+[^${VOWELS}]+[$VOWELS]+ ]]
}

# We do not double final letter when:
#   w or y at the end of words:
#     play – playing, played; snow - snowing, snowed;
#   a word ends in two consonants (-rt, -rn, etc.):
#     start – starting, started; burn - burn, burned;
#   two vowels come directly before it:
#     remain – remaining, remained.
stings.add_suffix.keep_last_char() {
  local value="${1}"
  [[ "${value}" =~ [${VOWELS}]$ ]] \
    || [[ "${value}" =~ [wy]$ ]] \
    || [[ "${value}" =~ [^${VOWELS}][^${VOWELS}]$ ]] \
    || [[ "${value}" =~ [${VOWELS}][${VOWELS}][^${VOWELS}]$ ]]
}


strings.mask() {
  local var_name="${1}" var_value="${2}"
  if [[ "${var_name,,}" =~ passw ]]; then
    echo "***MASKED***"
  else
    echo "${var_value}"
  fi
}

strings.squish() {
  read -r -d '' -a strings_array
  echo "${strings_array[*]}"
}

strings.underscore() {
  local str="${1}" result

  result="${str,,}"
  result="${result// /_}"

  echo "${result}"
}

to_lower(){
  local string="${1}"
  echo "${string,,}"
}

unquote() {
  sed -r -e "s/^'(.*)'\$/\\1/g" -e 's/^"(.*)"$/\1/g'
}


init "${@}"

action="${1}"
shift || true

assert_current_user_is_root

case "${action}" in
  install)
    kctl_auto_install '-I' 'kctl-install.log'
    ;;
  upgrade|update)
    kctl_auto_install '-U' 'kctl-update.log'
    ;;
  tune)
    kctl_auto_install '-T' 'kctl-tune.log'
    ;;
  repair|rescue|doctor)
    SKIP_CACHE=true kctl_auto_install '-R' "kctl-repair.log"
    ;;
  downgrade)
    SKIP_CACHE=true UPDATE_CHANNEL=stable kctl_auto_install '-U' "kctl-downgrade.log"
    ;;
  install-tracker)
    kctl_install_tracker "${@}"
    ;;
  certificates)
    kctl_certificates "${@}"
    ;;
  tracker-options|features)
    kctl.tracker_options "${@}"
    ;;
  use-clickhouse-olapdb)
    kctl.use_clickhouse_olapdb
    ;;
  podman)
    LOG_PATH=/dev/stderr kctl_podman "${@}"
    ;;
  resolvers)
    kctl_resolvers "${@}"
    ;;
  run)
    kctl_run "${@}"
    ;;
  check)
    kctl_check
    ;;
  reset|password-change)
    kctl.reset
    ;;
  transfers|transfer)
    kctl-transfers "${@}"
    ;;
  normalize)
    kctl.normalize
    ;;
  component|components)
    LOG_PATH=/dev/stderr kctl-components "${@}"
    ;;
  support-team-access)
    kctl.support_team_access "${@}"
    ;;
  help)
    LOG_PATH=/dev/null kctl_show_help
    ;;
  version)
    LOG_PATH=/dev/null kctl_show_version
    ;;
  "")
    LOG_PATH=/dev/null kctl_show_version
    ;;
  *)
    LOG_PATH=/dev/null fail "$(translate errors.invalid_options)"
esac
