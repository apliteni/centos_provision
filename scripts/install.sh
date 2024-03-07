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
  [[ "${CI}" != "" ]]
}

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

CACHING_PERIOD_IN_DAYS="2"
CACHING_PERIOD_IN_MINUTES="$((CACHING_PERIOD_IN_DAYS * 24 * 60))"

RELEASE_VERSION='2.45.4'
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

arrays.in() {
  local value="${1}"; shift
  local array=("${@}")

  [[ "$(arrays.index_of "${value}" "${array[@]}")" != "" ]]
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

get_centos_major_release() {
  grep -oP '(?<=release )\d+' /etc/centos-release
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

components.create_volumes() {
  local component="${1}" user group volumes_host_paths

  volumes_host_paths="$(components.get_volumes_host_paths "${component}")"

  if [[ "${volumes_host_paths}" == "" ]]; then
    return
  fi

  components.assert_var_is_set "${component}" "user"
  user="$(components.read_var "${component}" "user")"

  components.assert_var_is_set "${component}" "group"
  group="$(components.read_var "${component}" "group")"

  for volume_host_path in ${volumes_host_paths}; do
    components.create_volumes.init_volume "${volume_host_path}" "${user}" "${group}"
  done
}

components.create_volumes.init_volume() {
  local volume_host_path="${1}" user="${2}" group="${3}"

  if [[ ! "${volume_host_path}" =~ /$ ]]; then
    return
  fi

  if [[ ! -d "${volume_host_path}" ]]; then
    mkdir -p "${volume_host_path}"
  fi

  if components.is_own_volume_host_path "${volume_host_path}"; then
    chown "${user}:${group}" "${volume_host_path}"
  fi
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

components.fix_volumes_permissions() {
  local component="${1}" volumes_host_paths cmd

  volumes_host_paths="$(components.get_volumes_host_paths "${component}")"

  for volume in ${volumes_host_paths}; do
    if components.is_own_volume_host_path "${volume}"; then
      local cmd="true"
      cmd="${cmd} && $(components.fix_volumes_permissions.build_fix_owner_cmd "${component}" "${volume}")"
      cmd="${cmd} && $(components.fix_volumes_permissions.build_fix_directories_permissions_cmd "${component}" "${volume}")"
      cmd="${cmd} && $(components.fix_volumes_permissions.build_fix_files_permissions_cmd "${component}" "${volume}")"
      run_command "${cmd}" "Fixing ${volume} permissions"
    fi
  done
}

components.fix_volumes_permissions.build_fix_owner_cmd() {
  local component="${1}" volume="${2}"
  local user; user="$(components.read_var "${component}" "user")"
  local group; group="$(components.read_var "${component}" "group")"

  components.assert_var_is_set "${component}" "user"
  components.assert_var_is_set "${component}" "group"

  components.fix_volumes_permissions.build_fix_cmd \
          "${volume}" "-not \\( -user ${user} -and -group ${group} \\)" "chown ${user}:${group}"
}

components.fix_volumes_permissions.build_fix_directories_permissions_cmd() {
  local component="${1}" volume="${2}"
  local permissions conditions fix_cmd
  permissions="$(components.fix_volumes_permissions.get_custom_permissions "${component}" "${volume}")"

  if [[ "${permissions}" != "" ]]; then
    local directory_permissions="${permissions%%:*}"
    conditions="-type d -not -perm ${directory_permissions}"
    fix_cmd="chmod ${directory_permissions}"
  else
    conditions="-type d -and \\( -not -perm -u=rwx -or -perm /o=w \\)"
    fix_cmd="chmod u+rwx,o-w"
  fi

  components.fix_volumes_permissions.build_fix_cmd "${volume}" "${conditions}" "${fix_cmd}"
}

components.fix_volumes_permissions.build_fix_files_permissions_cmd() {
  local component="${1}" volume="${2}"
  local permissions conditions fix_cmd
  permissions="$(components.fix_volumes_permissions.get_custom_permissions "${component}" "${volume}")"

  if [[ "${permissions}" != "" ]]; then
    local file_permissions="${permissions##*:}"
    conditions="-type f -not -perm ${file_permissions}"
    fix_cmd="chmod ${file_permissions}"
  else
    conditions="-type f -and \\( -not -perm -u=rw -or -perm /a=x -or -perm /o=w \\)"
    fix_cmd="chmod u+rw,a-x,o-w"
  fi

  components.fix_volumes_permissions.build_fix_cmd "${volume}" "${conditions}" "${fix_cmd}"
}

components.fix_volumes_permissions.get_custom_permissions() {
  local component="${1}" volume="${2}"
  for volume_permissions in $(components.read_var "${component}" "volumes_permissions"); do
    local volume_permissions_path="${volume_permissions%%:*}"
    if [[ "${volume}" == "${volume_permissions_path}" ]]; then
      echo "${volume_permissions#*:}"
      return
    fi
  done
}

components.fix_volumes_permissions.build_fix_cmd() {
  local volume="${1}" conditions="${2}" fix_cmd="${3}"
  echo "find ${volume} ${conditions} -print0 | xargs -0 --no-run-if-empty --max-args=1000 ${fix_cmd}"
}

components.get_var_name() {
  local component="${1}" var="${2}"

  env_files.normalize_var_name "${component}_${var}"
}

components.get_volumes_host_paths() {
  local component="${1}" volumes

  volumes="$(components.read_var "${component}" "volumes")"

  for volume in ${volumes}; do
    local host_path="${volume%:*}"
    echo "${host_path}"
  done
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

components.is_own_volume_host_path() {
  local volume_host_path="${1}"
  
  for own_volume_prefix in /var/cache/ /var/log/ /var/lib/ /var/www/keitaro/; do
    if [[ "${volume_host_path}" =~ ^${own_volume_prefix} ]]; then
      return
    fi
  done

  false
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

gathering.gather_ansible_inventory_path() {
  paths=(/etc/keitaro/config/inventory /root/.keitaro/installer_config /root/.keitaro /root/hosts.txt)
  for path in "${paths[@]}"; do
    if [[ -f "${path}" ]]; then
      echo "${path}"
      return
    fi
  done
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
  if is_command_installed "${command}"; then
    debug "Command '$command' is installed"
  else
    debug "Command '$command' is not installed"
    return ${FAILURE_RESULT}
  fi
}

is_command_installed() {
  local command="${1}"
  if is_ci_mode; then
    sh -c "command -v '${command}'" > /dev/null
  else
    which "${command}" &>/dev/null
  fi
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

update_package() {
  local package="${1}"
  if is_package_installed "${package}"; then
    run_command "yum update -y ${package}" "Updating package ${package}" "hide_output"
  else
    debug "Package ${package} is not installed"
  fi
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
    if [[ -f "${TRACKER_ROOT}/${path}" ]] && [[ -f "${tracker_root}/${path}" ]]; then
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


KEITARO_ALREADY_INSTALLED_RESULT=0

DICT['en.messages.keitaro_already_installed']='Keitaro is already installed'
DICT['en.messages.validate_nginx_conf']='Checking nginx config'
DICT['en.messages.successful_install']='Keitaro has been installed!'
DICT['en.messages.successful_update']='Keitaro has been updated!'
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
DICT['en.validation_errors.validate_file_existence']='The file was not found by the specified path, please enter the correct path to the file'
DICT['en.validation_errors.validate_not_reserved_word']='You are not allowed to use yes/no/true/false as value'
DICT['en.validation_errors.validate_starts_with_latin_letter']='The value must begin with a Latin letter'


MINIMAL_RPM_VERSION='4.14'

packages.actualize_rpm() {
  local rpm_version

  if [[ "$(get_centos_major_release)" == "8" ]]; then
    rpm_version="$(rpm  --version | awk '{print $3}')"

    if versions.lt "${rpm_version}" "${MINIMAL_RPM_VERSION}"; then
      update_package 'rpm'
    fi
  fi
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
#   when REPLAY_ROLE_TAGS_ON_UPDATE_FROM=( ['init']='1.0' ['enable-swap']='2.0' )
#     and insalled version is 2.0
#     and we are updating to 2.14
#   then ansible tags will be expanded by `enable-swap` tag
declare -A REPLAY_ROLE_TAGS_SINCE=(
  ['apply-hot-fixes']='2.35.3'
  ['create-dirs']='2.38.2'
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
  ['tune-sysctl']='2.43.9'

  ['install-mariadb']='2.41.10'

  ['tune-nginx']='2.44.3'

  ['install-php']='2.43.7'
  ['setup-php']='2.38.2'
  ['tune-roadrunner']='2.44.1'
  ['tune']='2.42.9'
)

expand_ansible_tags_on_update() {
  local applied_kctl_version kctl_version

  if ! is_running_in_update_mode; then
    return
  fi
  debug "Update mode detected, expading ansible tags."

  applied_kctl_version=$(components.read_applied_var 'kctl' 'version')
  kctl_version=$(components.read_var 'kctl' 'version')
  debug "Updating ${applied_kctl_version} -> ${kctl_version}"
  expand_ansible_tags_with_update_tag
  expand_ansible_tags_with_tune_tag_on_changing_ram_size
  expand_ansible_tags_with_role_tags "${applied_kctl_version}"
  debug "ANSIBLE_TAGS is set to ${ANSIBLE_TAGS}"
}

expand_ansible_tags_with_update_tag() {
  expand_ansible_tags_with_tag "update"
}

expand_ansible_tags_with_tune_tag_on_changing_ram_size() {
  if inventory.is_variable_changed "ram_size_mb"; then
    debug "RAM size is changed, expanding ansible tags with 'tune'"
    expand_ansible_tags_with_tag "tune"
  else
    debug "RAM size is not changed"
  fi
}

expand_ansible_tags_with_role_tags() {
  local applied_kctl_version=${1}
  for role_tag in "${!REPLAY_ROLE_TAGS_SINCE[@]}"; do
    replay_role_tag_since=${REPLAY_ROLE_TAGS_SINCE[${role_tag}]}
    if versions.lte "${applied_kctl_version}" "${replay_role_tag_since}"; then
      expand_ansible_tags_with_tag "${role_tag}"
    fi
  done
}

clean_up() {
  popd &> /dev/null || true
}

is_running_in_update_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_UPDATE}" ]]
}

is_running_in_install_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_INSTALL}" ]]
}

is_running_in_repair_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_REPAIR}" ]]
}

is_running_in_tune_mode() {
  [[ "${RUNNING_MODE}" == "${RUNNING_MODE_TUNE}" ]]
}


RUNNING_MODE_INSTALL="install"
RUNNING_MODE_REPAIR="repair"
RUNNING_MODE_TUNE="tune"
RUNNING_MODE_UPDATE="update"
RUNNING_MODE="${RUNNING_MODE_INSTALL}"

parse_options(){
  while getopts ":CIRTUho:t:sv" option; do
    local option_value="${OPTARG}"
    ARGS["${option}"]="${option_value}"
    case "${option}" in
      C)
        print_deprecation_warning '-C option will be removed soon, use -R instead'
        RUNNING_MODE="${RUNNING_MODE_REPAIR}"
        ;;
      I)
        RUNNING_MODE="${RUNNING_MODE_INSTALL}"
        ;;
      R)
        RUNNING_MODE="${RUNNING_MODE_REPAIR}"
        ;;
      T)
        RUNNING_MODE="${RUNNING_MODE_TUNE}"
        ANSIBLE_TAGS='tune'
        ;;
      U)
        RUNNING_MODE="${RUNNING_MODE_UPDATE}"
        ;;
      h)
        help
        ;;
      t)
        print_deprecation_warning '-t option will be removed soon, use ANSIBLE_TAGS var to specify the tags'
        ANSIBLE_TAGS="${option_value}"
        ;;
      o)
        print_deprecation_warning '-o option will be removed soon, use LOG_PATH var to specify path to log file'
        LOG_PATH="${option_value}"
        ;;
      s)
        SKIP_CENTOS_RELEASE_CHECK="true"
        SKIP_FREE_SPACE_CHECK="true"
        ;;
      v)
        version
        ;;
      *)
        wrong_options
        ;;
    esac
  done
  ensure_options_correct
}

help_en(){
  echo "${SCRIPT_NAME} installs and configures Keitaro"
  echo
  echo "Example: ANSIBLE_IGNORE_TAGS=tune-swap LOG_PATH=/dev/stderr kctl-install"
  echo
  echo "Modes:"
  echo "  -U                       updates the system configuration and tracker"
  echo
  echo "  -R                       repairs the system configuration and tracker"
  echo
  echo "  -T                       tunes the system configuration and tracker"
  echo
  echo "Environment variables:"
  echo "  LOG_PAH                  sets the log output file"
  echo
  echo "  ANSIBLE_TAGS             sets ansible-playbook tags, ANSIBLE_TAGS=tag1[,tag2...]"
  echo
  echo "  ANSIBLE_IGNORE_TAGS      sets ansible-playbook ignore tags, ANSIBLE_IGNORE_TAGS=tag1[,tag2...]"
}

stage0() {
  debug "Starting stage 0: initial script setup"
  parse_options "$@"
  debug "Running in mode '${RUNNING_MODE}'"
}

stage1.install_components_env_origin() {
  local component_env_path
  local components_env_url="${COMPONENTS_ENV_URL:-}"

  if [[ "${components_env_url}" == "" ]]; then
    local keitaro_version="${KEITARO_VERSION:-}"

    if [[ "${keitaro_version}" == "" ]] || versions.lt "${keitaro_version}" "10.1"; then
      local update_channel; update_channel="$(stage1.install_components_env_origin.detect_update_channel)"
      stage1.install_components_env_origin.assert_update_channel_is_set_and_valid "${update_channel}"

      local release_api_url="${RELEASE_API_BASE_URL}/v2/releases/${update_channel}/latest"

      print_with_color "Requesting Keitaro version from ${update_channel} channel" 'blue'
      cache.download "${release_api_url}"

      keitaro_version="$(stage1.install_components_env_origin.get_remote_keitaro_version "${release_api_url}")"
      if [[ "${keitaro_version}" == "" ]]; then
        fail "Couldn't get remote Keitaro version"
      fi
    fi
    components_env_url="${FILES_KEITARO_ROOT_URL}/keitaro/keitaro/releases/${keitaro_version}/components.env"
  fi

  print_with_color 'Installing components.env' 'blue'
  cache.download "${components_env_url}"
  components_env_path="$(cache.path_by_url "${components_env_url}")"

  stage1.install_components_env_origin.install "${components_env_path}"
}

stage1.install_components_env_origin.get_remote_keitaro_version() {
  local url="${1}" path_to_response
  path_to_response="$(cache.path_by_url "${url}")"

  if [[ -f "${path_to_response}" ]] && jq -Mre '.version' "${path_to_response}" &> /dev/null; then
    jq -Mr '.version' "${path_to_response}"
  fi
}

stage1.install_components_env_origin.detect_update_channel() {
  local update_channel="${UPDATE_CHANNEL:-}"

  if [[ "${update_channel}" == "" ]]; then
    if is_running_in_install_mode; then
      update_channel="${DEFAULT_UPDATE_CHANNEL}"
    elif [[ -f /etc/keitaro/env/system.env ]]; then
      update_channel="$(env_files.read_var "/etc/keitaro/env/system.env" "update_channel")"
    fi
  fi

  echo "${update_channel}"
}

stage1.install_components_env_origin.assert_update_channel_is_set_and_valid() {
  local update_channel="${1}"

  if [[ "${update_channel}" == "" ]]; then
    fail "Variable UPDATE_CHANNEL is not set"
  fi

  if ! arrays.in "${update_channel}" "${UPDATE_CHANNELS[@]}"; then
    fail "Variable UPDATE_CHANNEL is set to unknown value '${update_channel}'. Supported channels are: ${UPDATE_CHANNELS[*]// /,}"
  fi
}

stage1.install_components_env_origin.install() {
  local components_env_path="${1}"

  if [[ ! -d "${PATH_TO_ENV_DIR}" ]]; then
    mkdir -p "${PATH_TO_ENV_DIR}"
  fi
  install -m 0600 "${components_env_path}" "${PATH_TO_COMPONENTS_ENV_ORIGIN}"
}

stage1.run_kctl_install() {
  local running_mode="${RUNNING_MODE:0:1}" # get first char from current mode - `i` for `install`, `u` for `update`
  local installer_mode="${running_mode^^}" # upcase it
  stage1.run_kctl_install.run "-${installer_mode}"
}

stage1.run_kctl_install.run() {
  local installer_mode="${1}" path_to_kctl_dist msg

  path_to_kctl_dist="$(components.build_path_to_preinstalled_directory 'kctl')"

  msg="Running \`ACTUAL_KCTL=true ${path_to_kctl_dist}/bin/kctl-install ${installer_mode}\`"
  debug "${msg}"; print_with_color "  ${msg}" 'blue'

  ACTUAL_KCTL=true exec "${path_to_kctl_dist}/bin/kctl-install" "${installer_mode}"
}

stage1.apply_hot_fixes() {
  if ! is_running_in_update_mode; then
    return
  fi

  stage1.apply_hot_fixes.fix_updating_kctld_from_0_3_2

  local kctl_version; kctl_version="$(components.read_var 'kctl' 'version')"
  local applied_kctl_version; applied_kctl_version="$(components.read_applied_var 'kctl' 'version')"

  if [[ "${kctl_version}" == '2.43.9' ]]; then
    stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9
  fi

  if versions.lt "${kctl_version}" '2.45' && versions.gte "${applied_kctl_version}" '2.45'; then
    stage1.apply_hot_fixes.fix_downgrading_kctl_from_2_45
  fi
}

stage1.apply_hot_fixes.fix_updating_kctld_from_0_3_2() {
  local var

  if [[ ! -f /opt/keitaro/bin/kctld-worker-0.3.2 ]] || [[ "${KCTLD_MODE}" == "" ]]; then
    return
  fi

  updates.print_checkpoint_info "Fix: reset env variables"
  debug 'unset KEITARO_VERSION' && unset "KEITARO_VERSION"
  for component in $(components.list_origin); do
    for suffix in "url" "version" "image"; do
      var="$(components.get_var_name "${component}" "${suffix}")"
      debug "unset ${var}" && unset "${var}"
    done
  done
}

stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9() {
  stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.fix_cache
  stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.fix_env_files
  stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.remove_systemd_timers
  export KCTL_IN_KCTL=true
}

stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.fix_cache() {
  local cmd
  local old_dir="/var/lib/kctl/kctl/83b3bc55dc2eab3270800fa36c7ed911/2.43.9"
  local new_dir="/var/lib/kctl/kctl/2.43.9/83b3bc55dc2eab3270800fa36c7ed911"

  if [[ ! -d "${old_dir}" ]]; then
    cmd="mkdir -p ${old_dir%/*}"
    cmd="${cmd} && ln -sf ${new_dir} ${old_dir}"
    updates.run_update_checkpoint_command "${cmd}" "Fix kctl dist dir to allow to downgrade kctl to 2.43.9"
  fi
}

stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.fix_env_files() {
  local cmd

  if [[ -d /etc/keitaro/backups/inventory ]]; then
    cmd="/bin/cp -f /etc/keitaro/backups/inventory/inventory /etc/keitaro/config/inventory"
    if [[ -f /etc/keitaro/backups/inventory/tracker.env ]]; then
      cmd="${cmd} && /bin/cp -f /etc/keitaro/backups/inventory/tracker.env /etc/keitaro/config/tracker.env"
      cmd="${cmd} && chown root:keitaro /etc/keitaro/config/tracker.env"
    fi
    if [[ -f /etc/keitaro/backups/inventory/system.env ]]; then
      cmd="${cmd} && /bin/cp -f /etc/keitaro/backups/inventory/system.env /etc/keitaro/env/system.env"
      cmd="${cmd} && chown root:keitaro /etc/keitaro/env/system.env"
    fi
    updates.run_update_checkpoint_command "${cmd}" "Restoring old inventory files to allow to downgrade kctl to 2.43.9"
  fi
}

stage1.apply_hot_fixes.fix_downgrading_kctl_from_2_45() {
  expand_ansible_tags_with_tag 'install-php'
  expand_ansible_tags_with_tag 'tune'
  for component in redis system-redis; do
    components.with_services_do "${component}" 'restart'
  done
  install_packages php74 php74-php-fpm php74-php-bcmath php74-php-devel php74-php-mysqlnd php74-php-opcache
  install_packages php74-php-pecl-redis php74-php-mbstring php74-php-pear php74-php-xml php74-php-pecl-zip
  install_packages php74-php-ioncube-loader php74-php-gd php74-php-intl php74-php-pecl-swoole4 fcgi
}

stage1.apply_hot_fixes.fix_downgrading_kctl_to_2_43_9.remove_systemd_timers() {
  systemd.uninstall "tracker-timers.target"
}

stage1.preinstall_kctl() {
  components.preinstall 'kctl'
  stage1.preinstall_kctl.install_components_envs
}

stage1.preinstall_kctl.install_components_envs() {
  local path_to_kctl; path_to_kctl="$(components.build_path_to_preinstalled_directory 'kctl')"
  print_with_color "Installing components env files from ${path_to_kctl}" 'blue'
  mkdir -p "${ROOT_PREFIX}/etc/keitaro/env/components/"
  install -m 0644 "${path_to_kctl}/files/etc/keitaro/env/components"/* "${ROOT_PREFIX}/etc/keitaro/env/components/"
  touch "${ROOT_PREFIX}/etc/keitaro/env/components/kctld.local.env"
}

stage1.generate_components_env() {
  stage1.generate_components_env.protect_components
  stage1.generate_components_env.generate
}

stage1.generate_components_env.protect_components() {
  for component in $(components.list_protected); do
    local version_var; version_var="$(env_files.normalize_var_name "${component}_version")"
    if [[ -v "${version_var}" ]]; then
      debug "Env var ${version_var} is set explicitely, force using ${!version_var} version for ${component}"
      continue
    fi
    new_version="$(components.read_origin_var "${component}" 'version')"
    applied_version="$(components.read_applied_var "${component}" 'version')"
    if [[ "${applied_version}" != "" ]] && versions.lt "${new_version}" "${applied_version}"; then
      updates.print_checkpoint_info "Protect ${component} from downgrading to ${new_version}, keep ${applied_version}"
      export "${version_var}=${applied_version}"
    fi
  done
}

stage1.generate_components_env.generate() {
  local components_template_path="${PATH_TO_COMPONENTS_ENV_ORIGIN}"
  local temp_path_1="${PATH_TO_COMPONENTS_ENV}.1" temp_path_2="${PATH_TO_COMPONENTS_ENV}.2"
  local redefined_env_vars
  updates.run_update_checkpoint_command "cp -f ${components_template_path} ${temp_path_1}" 'Generating components.env #1'
  for var in $(env_files.list_vars "${components_template_path}"); do
    if [[ -v "${var}" ]]; then
      redefined_env_vars="${redefined_env_vars} ${var}"
      env_files.forced_save_var "${temp_path_1}" "${var}" "${!var}"
    fi
  done
  local cmd="set -o allexport"
  cmd="${cmd} && source ${temp_path_1}"
  cmd="${cmd} && envsubst < ${temp_path_1} > ${temp_path_2}"
  cmd="${cmd} && rm -f ${temp_path_1}"
  cmd="${cmd} && mv -f ${temp_path_2} ${PATH_TO_COMPONENTS_ENV}"
  updates.run_update_checkpoint_command "${cmd}" 'Generating components.env #2'
}

stage1() {
  local path_to_kctl

  debug "Starting stage 1: Preinstall and run new KCTL"

  if [[ ! -f /usr/bin/jq ]]; then
    install_package jq
  fi

  if is_running_in_install_mode; then
    install_packages tar
  fi

  if [[ "${COMPONENTS_UPDATED:-}" == "" ]]; then
    if stage1.need_to_update_components_env_origin; then
      stage1.install_components_env_origin
    fi

    if stage1.need_to_regenerate_components_env; then
      stage1.generate_components_env
    fi
    export COMPONENTS_UPDATED=true
  fi

  if [[ "${ACTUAL_KCTL}" != "" ]]; then
    return
  fi

  if stage1.need_to_update_kctl_dist; then
    stage1.preinstall_kctl
    stage1.apply_hot_fixes
    stage1.run_kctl_install
  fi
}

stage1.need_to_update_components_env_origin() {
  is_running_in_install_mode \
    || is_running_in_update_mode
}

stage1.need_to_regenerate_components_env() {
  is_running_in_install_mode \
    || is_running_in_update_mode \
    || { is_running_in_repair_mode && [[ "${SKIP_CACHE}" != "" ]]; }
}

stage1.need_to_update_kctl_dist() {
  is_running_in_install_mode \
    || is_running_in_update_mode \
    || is_running_in_repair_mode
}

stage2() {
  debug "Starting stage 2: Run early update steps"

  if [[ "${ACTUAL_KCTL:-}" == "" ]]; then
    check_assertion 'Same process is not running'
  fi
  check_assertion 'Current user is root'

  updates.run 'early'
}

assert_keitaro_is_not_installed() {
  local applied_keitaro_version

  applied_keitaro_version="$(components.read_applied_var 'keitaro' 'version')"
  ansible_inventory_path="$(gathering.gather_ansible_inventory_path)"

  if [[ "${applied_keitaro_version}" != "" ]] || [[ "${ansible_inventory_path}" != "" ]]; then
    print_with_color "$(translate messages.keitaro_already_installed)" 'yellow'
    clean_up
    stage9.print_url
    exit "${KEITARO_ALREADY_INSTALLED_RESULT}"
  fi
}

assert_vm_is_not_openvz() {
  local virtualization_type; virtualization_type="$(gathering.gather 'virtualization_type')"

  if [[ "${virtualization_type}" == "openvz" ]]; then
    fail "Servers with OpenVZ virtualization are not supported"
  fi
}
MIN_RAM_SIZE_MB=1500

assert_server_has_enough_ram() {
  local current_ram_size_mb; current_ram_size_mb="$(gathering.gather 'ram_size_mb')"

  if [[ "${current_ram_size_mb}" -lt "${MIN_RAM_SIZE_MB}" ]]; then
    fail "$(translate errors.not_enough_ram)"
  fi
}

assert_package_httpd_is_not_installed() {
  if is_installed httpd; then
    fail "$(translate errors.apache_installed)"
  fi
}

assert_nginx_configs_are_correct() {
  if is_running_in_repair_mode || [[ "${SKIP_NGINX_CHECK:-}" != "" ]]; then
    print_with_color 'Running in repair mode - skip checking nginx configs' 'yellow'
    return
  fi
  if podman ps --format '{{.Names}}' | grep -q '^nginx$'; then
    local cmd="LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run nginx -t"
    local msg='Checking nginx config'
    run_command "${cmd}" "${msg}" "hide_output"
  else
    print_with_color "Couldn't find running nginx container, skip checking nginx configs" 'yellow'
  fi
}

assert_os_is_supported() {
  if ! file_exists /etc/centos-release; then
    fail "$(translate 'errors.wrong_distro')"
  fi
  if empty "${SKIP_CENTOS_RELEASE_CHECK}"; then
    if is_running_in_install_mode; then
      assert_centos_release_is_supportded
    fi
  fi
}

assert_centos_release_is_supportded(){
  if ! file_content_matches /etc/centos-release '-P' '^CentOS .* (8|9)\b'; then
    fail "$(translate 'errors.wrong_distro')"
  fi
}

assert_server_ip_is_valid() {
  local server_ip; server_ip="$(gathering.gather 'server_ip')"

  if ! valid_ip "${server_ip}"; then
    fail "$(translate 'errors.cant_detect_server_ip')"
  fi
}

valid_ip() {
  local value="${1}"
  [[ "$value" =~  ^[[:digit:]]+(\.[[:digit:]]+){3}$ ]] && valid_ip_segments "$value"
}


valid_ip_segments() {
  local ip="${1}"
  local segments
  IFS='.' read -r -a segments <<< "${ip}"
  for segment in "${segments[@]}"; do
    if ! valid_ip_segment "${segment}"; then
      return "${FAILURE_RESULT}"
    fi
  done
}

valid_ip_segment() {
  local ip_segment="${1}"
  [ "$ip_segment" -ge 0 ] && [ "$ip_segment" -le 255 ]
}

assert_architecture_is_supported() {
  if [[ "$(uname -m)" != "x86_64" ]]; then
    fail "$(translate errors.wrong_architecture)"
  fi
}
MIN_FREE_DISK_SPACE_MB=2048

assert_server_has_enough_free_disk_space() {
  if [[ "${SKIP_FREE_SPACE_CHECK}" != "" ]] || is_running_in_repair_mode; then
    debug "Free disk space checking skipped"
    return
  fi

  local disk_free_size_mb; disk_free_size_mb="$(gathering.gather 'disk_free_size_mb')"

  if [[ "${disk_free_size_mb}" -lt "${MIN_FREE_DISK_SPACE_MB}" ]]; then
    fail "$(translate errors.not_enough_free_disk_space)"
  fi
}


assert_thp_is_deactivatable() {
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
    fail "There are no THP files in /sys fs"
  fi
}

are_thp_sys_files_existing() {
  file_exists "/sys/kernel/mm/transparent_hugepage/enabled" && file_exists "/sys/kernel/mm/transparent_hugepage/defrag"
}

assert_systemd_works_properly() {
  if ! systemctl &> /dev/null; then
    fail "$(translate errors.systemctl_doesnt_work_properly)"
  fi
}

stage3() {
  debug 'Starting stage 3: check assertions'

  check_assertion 'Package httpd is not installed'
  check_assertion 'Server has enough free disk space'
  if is_running_in_install_mode; then
    check_assertion 'Keitaro is not installed'
    check_assertion 'OS is supported'
    check_assertion 'Architecture is supported'
    check_assertion 'Server has enough RAM'
    check_assertion 'SystemD works properly'
    check_assertion 'VM is not OpenVZ'
    check_assertion 'THP is deactivatable'
    check_assertion 'Server IP is valid'
  else
    check_assertion 'Nginx configs are correct'
  fi

  print_with_color 'All assertions have passed' 'green'
}

stage4.init_inventory() {
  stage4.init_inventory.init_clickhouse_entries
  stage4.init_inventory.init_mariadb_entries
  stage4.init_inventory.init_redis_entries 'redis'
  stage4.init_inventory.init_redis_entries 'system-redis'
  stage4.init_inventory.init_tracker_entries
  stage4.init_inventory.init_system_entries
}

stage4.init_inventory.init_mariadb_entries() {
  stage4.init_inventory.init_var 'mariadb_storage_engine' 'innodb'

  stage4.init_inventory.init_var 'mariadb_keitaro_database' 'keitaro'
  stage4.init_inventory.init_var 'mariadb_keitaro_user'     'keitaro'
  stage4.init_inventory.init_var 'mariadb_keitaro_password' "$(generate_16hex)"

  stage4.init_inventory.init_var 'mariadb_system_database'  'mysql'
  stage4.init_inventory.init_var 'mariadb_system_user'      'root'
  stage4.init_inventory.init_var 'mariadb_system_password'  "$(generate_16hex)"
}

stage4.init_inventory.init_redis_entries() {
  local var_prefix="${1}"
  inventory.save_var "${var_prefix}_keitaro_database" '1'
}

stage4.init_inventory.init_var() {
  local variable="${1}"
  local new_value="${2}"
  local old_value

  old_value="$(inventory.read_var "${variable}")"

  if [[ "${old_value}" == "" ]]; then
    inventory.save_var "${variable}" "${new_value}"
  fi
}

stage4.init_inventory.init_system_entries() {
  stage4.init_inventory.init_var 'olap_db' 'clickhouse'
}

stage4.init_inventory.init_clickhouse_entries() {
  stage4.init_inventory.init_clickhouse_entries.init_for_user_and_database 'keitaro' 'keitaro'
  stage4.init_inventory.init_clickhouse_entries.init_for_user_and_database 'root' 'system'
}

stage4.init_inventory.init_clickhouse_entries.init_for_user_and_database() {
  local user="${1}" database="${2}" password

  password="$(inventory.read_var "clickhouse_${database}_password")"
  if [[ "${password}" == "" ]]; then
    password="$(generate_16hex)"
  fi

  inventory.save_var "clickhouse_${database}_database" "${database}"
  inventory.save_var "clickhouse_${database}_user"     "${user}"
  inventory.save_var "clickhouse_${database}_password" "${password}"
}

stage4.init_inventory.init_tracker_entries() {
  stage4.init_inventory.init_var 'tracker_options' ''
  stage4.init_inventory.init_var 'tracker_postback_key' ''
  stage4.init_inventory.init_var 'tracker_salt' "$(generate_16hex)"
  stage4.init_inventory.init_var 'tracker_tables_prefix' 'keitaro_'
}

stage4.gather_and_save_hw_vars() {
  debug "Saving hardware related variables"
  stage4.gather_and_save_hw_vars.for_var 'cpu_cores'
  stage4.gather_and_save_hw_vars.for_var 'ram_size_mb'
  stage4.gather_and_save_hw_vars.for_var 'server_ip'
  stage4.gather_and_save_hw_vars.for_var 'ssh_port'
}

stage4.gather_and_save_hw_vars.for_var() {
  local var_name="${1}" value fn_name

  value="$(gathering.gather "${var_name}")"

  if [[ "${value}" == "" ]]; then
    fail "Couldn't detect hw var ${var_name}"
  fi

  inventory.save_var "${var_name}" "${value}"
}

stage4.init_applied_env() {
  touch "${PATH_TO_APPLIED_ENV}"
}

stage4() {
  debug "Starting stage 4: generate env files"

  if is_running_in_install_mode; then
    stage4.init_applied_env
    stage4.init_inventory
  fi

  stage4.gather_and_save_hw_vars
}

FASTESTMIROR_CONF_PATH="/etc/yum/pluginconf.d/fastestmirror.conf"

stage5.disable_fastestmirror(){
  local disabling_message="Disabling mirrors in repo files"
  local disabling_command="sed -i -e 's/^#baseurl/baseurl/g; s/^mirrorlist/#mirrorlist/g;'  /etc/yum.repos.d/*"
  run_command "${disabling_command}" "${disabling_message}" "hide_output"

  if [[ "$(get_centos_major_release)" == "7" ]] && stage5.is_fastestmirror_enabled; then
    disabling_message="Disabling fastestmirror plugin on Centos7"
    disabling_command="sed -i -e 's/^enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf"
    run_command "${disabling_command}" "${disabling_message}" "hide_output"
  fi
}

stage5.is_fastestmirror_enabled() {
  file_exists "${FASTESTMIROR_CONF_PATH}" && \
      grep -q '^enabled=1' "${FASTESTMIROR_CONF_PATH}"
}

stage5.install_core_packages() {
  install_packages crontabs logrotate unzip gettext podman-docker

  if [[ "$(get_centos_major_release)" == "8" ]]; then
    install_package 'libseccomp-devel'
  fi
}

stage5.actualize_distro() {
  if stage5.actualize_distro.is_centos8_distro; then
    stage5.actualize_distro.switch_to_centos8_stream
    stage5.disable_fastestmirror
    stage5.clean_packages_metadata
  fi
}

stage5.actualize_distro.is_centos8_distro() {
  file_content_matches /etc/centos-release '-P' '^CentOS Linux.* 8\b'
}

stage5.actualize_distro.switch_to_centos8_stream() {
  local repo_base_url="http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages"
  local release="8-6"
  local gpg_keys_package_url="${repo_base_url}/centos-gpg-keys-${release}.el8.noarch.rpm"
  local repos_package_url="${repo_base_url}/centos-stream-repos-${release}.el8.noarch.rpm"
  debug 'Switching CentOS 8 -> CentOS Stream 8'
  print_with_color 'Switching CentOS 8 -> CentOS Stream 8:' 'blue'
  run_command "dnf install -y --nobest --allowerasing ${gpg_keys_package_url} ${repos_package_url}" \
              "  Installing CentOS Stream repos"
  run_command "dnf distro-sync -y" "  Syncing distro"
}

stage5.clean_packages_metadata() {
  if [[ "${SKIP_YUM_UPDATE}" == "" ]]; then
    run_command "yum clean all" "Cleaninig yum meta" "hide_output"
  fi
}

stage5.disable_selinux() {
  if [[ "$(getenforce)" == "Enforcing" ]]; then
    run_command 'setenforce 0' 'Disabling Selinux' 'hide_output'
  fi

  if file_exists /usr/sbin/setroubleshootd; then
    run_command 'yum erase setroubleshoot-server -y && systemctl daemon-reload' 'Removing setroubleshootd' 'hide_output'
  fi
}

stage5.install_kctl() {
  debug "Install KCTL"

  components.with_services_do 'kctl' 'stop'

  stage5.install_kctl.install_kctl_files

  stage5.install_kctl.uninstall_redundant_components

  if is_running_in_repair_mode; then
    stage5.install_kctl.reset_podman
  fi

  stage5.install_kctl.install_components
}

stage5.install_extra_packages() {
  stage5.install_extra_packages.install_epel_release
  stage5.install_extra_packages.install_packages
  stage5.install_extra_packages.install_chrony
}

stage5.install_extra_packages.install_chrony() {
  install_packages chrony
  systemd.enable_and_start_service chronyd
}

stage5.install_extra_packages.install_packages() {
  install_packages bind-utils git htop httpd-tools lsof nano python3 python3-pip rsync
  install_packages socat strace sudo unzip openssl screen
}

stage5.install_extra_packages.install_epel_release() {
  if stage5.install_extra_packages.need_to_install_epel_repo; then
    local cmd="cp /etc/keitaro/config/epel.repo /etc/yum.repos.d/ && yum clean all"
    run_command "${cmd}" "Preinstalling EPEL repo" "hide_output"
  fi
  install_package epel-release
}

stage5.install_extra_packages.need_to_install_epel_repo() {
  local centos_release; centos_release="$(get_centos_major_release)"
  [[ "${centos_release}" == "9" ]] \
    && ! stage5.install_extra_packages.is_repo_installed epel \
    && ! stage5.install_extra_packages.is_repo_installed extras-common
}

stage5.install_extra_packages.is_repo_installed() {
  local repo_name="${1}"
  dnf repolist all | awk '{print $1}' | grep -q "^${repo_name}\$"
}

PATH_TO_CONTAINERS_DIR="/var/lib/containers/"

stage5.install_kctl.reset_podman() {
  local msg cmd

  if [[ "${RESET_PODMAN:-}" == "" ]]; then
    msg="Skip resetting podman - RESET_PODMAN is not set. Run \`RESET_PODMAN=true kctl repair\`"
    print_with_color "${msg}" 'yellow'; debug "${msg}"
    return
  fi

  msg='Resetting podman'; print_with_color "${msg}" 'yellow'; debug "${msg}"

  for component in $(components.list_origin | tac); do
    components.with_services_do "${component}" "stop"
  done

  cmd="mount"
  cmd="${cmd} | { grep -F ${PATH_TO_CONTAINERS_DIR} || [[ \$? == 1 ]] ; }"
  cmd="${cmd} | awk '/^shm/ {print \$3}'"
  cmd="${cmd} | xargs --no-run-if-empty umount"
  run_command "${cmd}" 'Unmounting Podman SHM entries'

  cmd="rm -rf ${PATH_TO_CONTAINERS_DIR}"
  run_command "${cmd}" 'Removing Podman FS entries'

  msg='Podman reset'; print_with_color "${msg}" 'green'; debug "${msg}"
}

stage5.install_kctl.run_after_update_admin_component_hook() {
  updates.run_update_checkpoint_command "rm -f ${TRACKER_ROOT}/cache_locales/*.php" "Clearing locales cache"
  updates.run_update_checkpoint_command "${KCTL_BIN_DIR}/kctl-monitor" "Updating stats.json"
}

stage5.install_kctl.uninstall_redundant_components() {
  for redundant_component in $(components.list_redundant); do
    components.uninstall "${redundant_component}"
  done
}

stage5.install_kctl.install_kctl_files() {
  local path_to_kctl

  path_to_kctl="$(components.build_path_to_preinstalled_directory 'kctl')"

  stage5.install_kctl.install_binaries "${path_to_kctl}"
  stage5.install_kctl.install_configs "${path_to_kctl}"

  systemd.daemon_reload
}

stage5.install_kctl.install_binaries() {
  local path_to_kctl="${1}" version url msg

  msg="Installing kctl binaries from ${path_to_kctl}"
  debug "${msg}"; print_with_color "${msg}" "blue"

  install "${path_to_kctl}"/bin/* "${KCTL_BIN_DIR}"/

  for existing_file_path in "${KCTL_BIN_DIR}"/*; do
    local file_name="${existing_file_path##*/}"
    ln -s -f "${existing_file_path}" "/usr/local/bin/${file_name}"
  done

  install -m 0755 "${path_to_kctl}/files/bin/"* "${ROOT_PREFIX}/usr/local/bin/"
}

stage5.install_kctl.install_configs() {
  local path_to_kctl="${1}"

  mkdir -p "${ROOT_PREFIX}/etc/containers/registries.conf.d/"
  mkdir -p "${ROOT_PREFIX}/etc/keitaro/config/"
  mkdir -p "${ROOT_PREFIX}/etc/nginx/"

  install -m 0444 "${path_to_kctl}/files/etc/sudoers.d"/* "${ROOT_PREFIX}/etc/sudoers.d/"
  install -m 0644 "${path_to_kctl}/files/etc/systemd/system"/* "${ROOT_PREFIX}/etc/systemd/system/"
  install -m 0644 "${path_to_kctl}/files/etc/keitaro/config"/* "${ROOT_PREFIX}/etc/keitaro/config/"
  install -m 0644 "${path_to_kctl}/files/etc/logrotate.d"/* "${ROOT_PREFIX}/etc/logrotate.d"/
  install -m 0644 "${path_to_kctl}/files/etc/nginx"/* "${ROOT_PREFIX}/etc/nginx/"
  install -m 0644 "${path_to_kctl}/files/etc/containers"/nodocker "${ROOT_PREFIX}/etc/containers/"

  if [[ "$(get_centos_major_release)" != "7" ]]; then
    install -m 0644 "${path_to_kctl}/files/etc/containers/registries.conf.d"/* \
            "${ROOT_PREFIX}/etc/containers/registries.conf.d/"
  fi
}

stage5.install_kctl.install_components() {
  for component in $(components.list_origin); do
    if [[ "${component}" == 'kctl' ]]; then
      continue
    fi

    if stage5.install_kctl.need_to_stop_services "${component}"; then
      components.with_services_do "${component}" 'stop'
    fi

    if stage5.install_kctl.need_to_update_component "${component}"; then
      stage5.install_kctl.update_component "${component}"
    fi

    if stage5.install_kctl.need_to_start_services "${component}"; then
      components.with_services_do "${component}" 'start'
      stage5.install_kctl.wait_until_is_up "${component}"
    fi

    if stage5.install_kctl.need_to_restart_services "${component}"; then
      components.with_services_do "${component}" 'restart'
      stage5.install_kctl.wait_until_is_up "${component}"
    fi

    if stage5.install_kctl.need_to_enable_services "${component}"; then
      components.with_services_do "${component}" 'enable'
    fi

    if stage5.install_kctl.need_to_update_component "${component}" && [[ "${component}" == "admin" ]]; then
      stage5.install_kctl.run_after_update_admin_component_hook
    fi
  done
}

stage5.install_kctl.wait_until_is_up() {
  local component="${1}"

  if is_running_in_repair_mode && [[ "${component}" == 'nginx' ]]; then
    print_with_color "  Running in repair mode - do not wait for Nginx to start accepting connections" "yellow"
  else
    components.wait_until_is_up "${component}"
  fi
}

stage5.install_kctl.is_component_updateable() {
  local component="${1}"
  is_running_in_repair_mode || { is_running_in_update_mode && components.is_changed "${component}"; }
}

stage5.install_kctl.need_to_update_component() {
  local component="${1}"
  is_running_in_install_mode || stage5.install_kctl.is_component_updateable "${component}"
}

stage5.install_kctl.update_component() {
  local component="${1}" image
  image="$(components.read_var "${component}" 'image')"

  if [[ "${image}" != "" ]]; then
    components.install_image "${component}"
  else
    components.install_binaries "${component}"
  fi
}

stage5.install_kctl.need_to_enable_services() {
  local component="${1}"
  [[ "${component}" != 'nginx-starting-page' ]]
}

stage5.install_kctl.need_to_stop_services() {
  local component="${1}"
  ! is_running_in_install_mode && [[ "${component}" == 'nginx-starting-page' ]]
}

stage5.install_kctl.need_to_start_services() {
  local component="${1}"
  is_running_in_install_mode && [[ "${component}" != 'nginx' ]]
}

stage5.install_kctl.need_to_restart_services() {
  local component="${1}"
  [[ "${component}" != 'nginx-starting-page' ]] \
    && ! { [[ "${component}" == "kctld" ]] && [[ "${KCTLD_MODE:-}" != '' ]]; } \
    && { stage5.install_kctl.is_component_updateable "${component}" || is_running_in_tune_mode; }
}

stage5() {
  debug "Starting stage 5: update current and install necessary packages"

  if is_running_in_install_mode || is_running_in_repair_mode; then
    stage5.disable_selinux
    stage5.disable_fastestmirror
    stage5.clean_packages_metadata
  fi

  if is_running_in_install_mode; then
    stage5.actualize_distro
    stage5.install_core_packages
    system.users.create "${KEITARO_SUPPORT_USER}" "${KEITARO_SUPPORT_HOME_DIR}"
  fi

  stage5.install_kctl
  tracker.generate_artefacts

  if is_running_in_install_mode; then
    stage5.install_extra_packages
    systemd.enable_and_start_service 'podman'
    systemd.enable_and_start_service 'logrotate.timer'
  fi
}

stage6() {
  debug "Running stage6"
  updates.run 'middle'
}

ANSIBLE_TASK_HEADER="^TASK \[(.*)\].*"
ANSIBLE_TASK_FAILURE_HEADER="^(fatal|failed): \[localhost\]: [A-Z]+! => "
ANSIBLE_LAST_TASK_LOG="${WORKING_DIR}/ansible_last_task.log"

stage7.run_ansible_playbook() {
  local env cmd applied_tracker_version tracker_version tracker_directory playbook_directory

  playbook_directory="$(components.build_path_to_preinstalled_directory "${KCTL_COMPONENT}")/playbook"
  tracker_directory="$(components.build_path_to_preinstalled_directory "${TRACKER_COMPONENT}")"

  env="${env} ANSIBLE_FORCE_COLOR=true"
  env="${env} ANSIBLE_CONFIG=${playbook_directory}/ansible.cfg"
  env="${env} RUNNING_MODE=${RUNNING_MODE}"
  env="${env} TRACKER_DIRECTORY=${tracker_directory}"

  cmd="set -o allexport"
  cmd="${cmd} && source ${PATH_TO_COMPONENTS_ENV}"
  for component in $(components.list_origin); do
    cmd="${cmd} && source ${PATH_TO_ENV_DIR}/components/${component}.env"
  done
  if [[ -f "${PATH_TO_APPLIED_ENV}" ]]; then
    cmd="${cmd} && source ${PATH_TO_APPLIED_ENV}"
  fi
  cmd="${cmd} && source ${PATH_TO_INVENTORY_ENV}"
  cmd="${cmd} && ${env} $(get_ansible_playbook_command) -v -i localhost, --connection=local ${playbook_directory}/playbook.yml"

  expand_ansible_tags_on_update

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

stage7.install_ansible() {
  install_package "$(stage7.get_ansible_package_name)"
  stage7.install_ansible_collection "containers.podman"
  stage7.install_ansible_collection "community.general"
  stage7.install_ansible_collection "ansible.posix"
}


stage7.get_ansible_package_name() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "ansible-python3"
  else
    echo "ansible-core"
  fi
}

stage7.install_ansible_collection() {
  local collection="${1}"
  local package="${collection//\./-}.tar.gz"
  local collection_url="${FILES_KEITARO_ROOT_URL}/scripts/ansible-galaxy-collections/${package}"
  local cmd

  if ! stage7.is_ansible_collection_installed "${collection}"; then
    cmd="$(stage7.get_ansible_galaxy_command) collection install ${collection_url} --force"
    run_command "${cmd}" "Installing ansible galaxy collection ${collection}" "hide"
  fi
}

stage7.is_ansible_collection_installed() {
  local collection="${1}"
  [[ -d "/root/.ansible/collections/ansible_collections/${collection//.//}" ]]
}

stage7.get_ansible_galaxy_command() {
  if [[ "$(get_centos_major_release)" == "7" ]]; then
    echo "LC_ALL=C ansible-galaxy-3"
  else
    echo "LC_ALL=C.UTF-8 ansible-galaxy"
  fi
}

stage7() {
  debug "Starting stage 7: run ansible playbook"
  stage7.install_ansible
  stage7.run_ansible_playbook
  clean_up
}

stage8.shedule_kctld_restart() {
  local kctld_port; kctld_port="$(components.read_var kctld port)"
  local cmd="LOG_PATH=/dev/stderr KCTLD_PORT=${kctld_port} ${KCTL_BIN_DIR}/kctld-cli --command restart"
  run_command "${cmd}" "Schedule restarting KCTLD"
}

stage8.update_applied_vars() {
  stage8.update_applied_vars.inventory

  if ! is_running_in_tune_mode; then
    stage8.update_applied_vars.components
  fi
}

stage8.update_applied_vars.inventory() {
  inventory.update_applied_var 'cpu_cores'
  inventory.update_applied_var 'mariadb_storage_engine'
  inventory.update_applied_var 'olap_db'
  inventory.update_applied_var 'ram_size_mb'
}

stage8.update_applied_vars.components() {
  for component in $(components.list_origin); do
    components.update_applied_vars "${component}"
  done
  components.update_applied_vars 'keitaro'
}

stage8() {
  debug "Starting stage 8: run post update/install steps"
  updates.run 'post'

  components.with_services_do 'kctl' 'start'
  components.with_services_do 'kctl' 'enable'

  stage8.update_applied_vars
  stage8.shedule_kctld_restart
}

stage9.print_successful_message(){
  print_with_color "$(translate "messages.successful_${RUNNING_MODE}")" 'green'
  print_with_color "$(translate 'messages.visit_url')" 'green'
  stage9.print_url
}

stage9.print_url() {
  local server_ip; server_ip="$(inventory.read_var 'server_ip')"
  print_with_color "http://${server_ip}/admin" 'light.green'
}

stage9.update_packages() {
  if [[ "${SKIP_YUM_UPDATE}" != "" ]] || is_running_in_tune_mode; then
    return
  fi

  debug "Updating packages"
  cmd='yum update -y'

  if [[ "$(get_centos_major_release)" != "7" ]]; then
    cmd="${cmd} --nobest"
  fi

  if run_command "${cmd}" "" "" "allow_errors"; then
    print_with_color 'All packages has been succesfully updated' 'green'
  else
    debug 'There were errors packages while updating system packages. See log for details'
    print_with_color 'There were errors packages while updating system packages' 'red'
  fi
}

stage9() {
  debug "Starting stage 9: Update packages"

  if is_running_in_install_mode || is_running_in_update_mode; then
    stage9.update_packages
  fi
  stage9.print_successful_message
}

updates.early.since_2_44_1() {
  systemd.stop_service 'kctl-monitor'

  stage5.actualize_distro
  stage5.install_core_packages
  stage5.install_extra_packages
  system.users.create "${KEITARO_SUPPORT_USER}" "${KEITARO_SUPPORT_HOME_DIR}"
}

updates.early.since_2_45_2() {
  updates.early.since_2_45_2.remove_old_php_packages
  updates.early.since_2_45_2.remove_old_systemd_services
  updates.early.since_2_45_2.remove_old_nginx_configs
}

updates.early.since_2_45_2.remove_old_php_packages() {
  cmd="yum erase -y 'php5*' 'php70*' 'php71*' 'php72*' 'php73*'"
  updates.run_update_checkpoint_command "${cmd}" "Removing old PHP packages"
}

updates.early.since_2_45_2.remove_old_systemd_services() {
  systemd.disable_and_stop_service disable-thp
  systemd.disable_and_stop_service schedule-fs-check-on-boot
  cmd="rm -f /etc/systemd/system/{disable-thp,schedule-fs-check-on-boot}.service"
  updates.run_update_checkpoint_command "${cmd}" "Removing old SystemD services"
}

updates.early.since_2_45_2.remove_old_nginx_configs() {
  cmd="rm -f /etc/nginx/conf.d/*.conf.202[2-4][0-1][0-9][0-3][0-9][0-5][0-9][0-5][0-9][0-5][0-9]"
  updates.run_update_checkpoint_command "${cmd}" "Removing old Nginx config backups"
}

updates.early.since_2_30_0() {
  updates.early.since_2_30_0.remove_docker_ce_packages
}

updates.early.since_2_30_0.remove_docker_ce_packages() {
  local cmd="yum erase -y docker* containerd"
  updates.run_update_checkpoint_command "${cmd}" "Removing Docker CE packages"
}

PATH_TO_BACKUP_INVENTORY_DIR="${ETC_DIR}/backups/inventory"

updates.early.since_2_43_9.backup_old_inventory_files() {
  local ansible_inventory_path="${1}" cmd

  cmd="mkdir -p ${PATH_TO_BACKUP_INVENTORY_DIR}"
  if [[ -f "${ansible_inventory_path}" ]]; then
    cmd="${cmd} && /bin/cp -f ${ansible_inventory_path} ${PATH_TO_BACKUP_INVENTORY_DIR}/inventory"
  fi
  if [[ -f /etc/keitaro/config/tracker.env ]]; then
    cmd="${cmd} && /bin/cp -f /etc/keitaro/config/tracker.env ${PATH_TO_BACKUP_INVENTORY_DIR}/tracker.env"
  fi
  if [[ -f /etc/keitaro/env/system.env ]]; then
    cmd="${cmd} && /bin/cp -f /etc/keitaro/env/system.env ${PATH_TO_BACKUP_INVENTORY_DIR}/system.env"
  fi

  updates.run_update_checkpoint_command "${cmd}" "Backing up old inventory files"
}

updates.early.since_2_43_9.gather_value() {
  local tracker_env_var="${1^^}"
  local ansible_inventory_var="${2:-${tracker_env_var}}"; ansible_inventory_var="${ansible_inventory_var,,}"
  local tracker_config_var="${3:-${ansible_inventory_var}}"; tracker_config_var="${tracker_config_var,,}"
  local value

  local path_to_tracker_config="/var/www/keitaro/application/config/config.ini.php"
  local path_to_tracker_env="${ROOT_PREFIX}/etc/keitaro/config/tracker.env"
  local ansible_inventory_paths=(
      "${ROOT_PREFIX}/etc/keitaro/config/inventory"
      "${ROOT_PREFIX}/root/.keitaro/installer_config"
      "${ROOT_PREFIX}/root/.keitaro"
      "${ROOT_PREFIX}/root/hosts.txt")

  value="$(env_files.read_var "${path_to_tracker_env}" "${tracker_env_var}")"
  if [[ "${value}" != "" ]]; then
    local masked_value; masked_value="$(strings.mask "${tracker_env_var}" "${value}")"
    debug "Got ${tracker_env_var} from ${path_to_tracker_env}: '${masked_value}'"
  fi

  if [[ "${value}" == "" ]]; then
    for path_to_ansible_inventory in "${ansible_inventory_paths[@]}"; do
      if [[ -f "${path_to_ansible_inventory}" ]]; then
        value="$(updates.early.since_2_43_9.read_config_value "${path_to_ansible_inventory}" "${ansible_inventory_var}")"
        break
      fi
    done
  fi

  if [[ "${value}" == "" ]]; then
    value="$(updates.early.since_2_43_9.read_config_value "${path_to_tracker_config}" "${tracker_config_var}")"
  fi

  if [[ "${value}" == "" ]]; then
    debug "WARN: Couldn't detect ${tracker_env_var}"
  fi

  echo "${value}"
}

updates.early.since_2_43_9.migrate_inventory() {
  local path_to_temp_inventory_env="${PATH_TO_INVENTORY_ENV}.tmp"

  updates.early.since_2_43_9.migrate_inventory.clickhouse_entries "${path_to_temp_inventory_env}"
  updates.print_checkpoint_info "Migrated Clickhouse inventory entries"

  updates.early.since_2_43_9.migrate_inventory.mariadb_entries "${path_to_temp_inventory_env}"
  updates.print_checkpoint_info "Migrated MariaDB inventory entries"

  updates.early.since_2_43_9.migrate_inventory.redis_entries "${path_to_temp_inventory_env}"
  updates.print_checkpoint_info "Migrated Redis inventory entries"

  updates.early.since_2_43_9.migrate_inventory.tracker_entries "${path_to_temp_inventory_env}"
  updates.print_checkpoint_info "Migrated tracker inventory entries"

  updates.early.since_2_43_9.migrate_inventory.system_entries "${path_to_temp_inventory_env}"
  updates.print_checkpoint_info "Migrated system inventory entries"
}

updates.early.since_2_43_9.migrate_inventory.system_entries() {
  local path_to_inventory_env="${1}" value

  value="$(components.read_applied_var 'kctl' 'version')"
  if [[ "${value}" == "" ]]; then
    value="$(updates.early.since_2_43_9.gather_value 'installer_version')"
  fi
  if [[ "${value}" == "" ]]; then
    value="${VERY_FIRST_VERSION}"
  fi
  env_files.save_applied_var 'kctl_version' "${value}"

  value="$(updates.early.since_2_43_9.gather_value 'olap_db')"
  if [[ "${value}" != "${OLAP_DB_CLICKHOUSE}" ]]; then
    value="${OLAP_DB_MARIADB}"
    local features; features="$(updates.early.since_2_43_9.gather_value 'features')"
    if [[ "${features}" =~ rbooster ]]; then
      value="${OLAP_DB_CLICKHOUSE}"
    fi
  fi
  env_files.forced_save_var "${path_to_inventory_env}" 'olap_db' "${value}"
}

updates.early.since_2_43_9.migrate_inventory.clickhouse_entries() {
  local path_to_inventory_env="${1}" keitaro_password system_password

  keitaro_user_password="$(updates.early.since_2_43_9.gather_value 'ch_password')"
  updates.early.since_2_43_9.migrate_inventory.clickhouse_entries.migrate_for_user_and_database \
          'keitaro' 'keitaro' "${keitaro_user_password}"

  updates.early.since_2_43_9.migrate_inventory.clickhouse_entries.migrate_for_user_and_database \
          'root' 'system'
}

updates.early.since_2_43_9.migrate_inventory.clickhouse_entries.migrate_for_user_and_database() {
  local user="${1}" database="${2}" password="${3:-}"

  if [[ "${password}" == "" ]]; then
    password="$(generate_16hex)"
  fi

  env_files.forced_save_var "${path_to_inventory_env}" "clickhouse_${database}_database"  "${database}"
  env_files.forced_save_var "${path_to_inventory_env}" "clickhouse_${database}_user"      "${user}"
  env_files.forced_save_var "${path_to_inventory_env}" "clickhouse_${database}_password"  "${password}"
}

updates.early.since_2_43_9.migrate_inventory.mariadb_entries() {
  local path_to_inventory_env="${1}" value

  value="$(updates.early.since_2_43_9.migrate_inventory.mariadb_entries.detect_storage_engine)"
  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_storage_engine' "${value}"

  updates.early.since_2_43_9.migrate_inventory.mariadb_keitaro_entries "${path_to_inventory_env}"
  updates.early.since_2_43_9.migrate_inventory.mariadb_system_entries  "${path_to_inventory_env}"

}

updates.early.since_2_43_9.migrate_inventory.mariadb_keitaro_entries() {
  local path_to_inventory_env="${1}" value password

  value="$(updates.early.since_2_43_9.gather_value 'mariadb_db' 'db_name' 'db/name')"
  updates.early.since_2_43_9.assert_value_is_set "${value}" 'MariaDB Keitaro database'
  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_keitaro_database' "${value}"

  value="$(updates.early.since_2_43_9.gather_value 'mariadb_username' 'db_user' 'db/user')"
  updates.early.since_2_43_9.assert_value_is_set "${value}" 'MariaDB Keitaro user'
  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_keitaro_user' "${value}"

  password="$(updates.early.since_2_43_9.gather_value 'mariadb_password' 'db_password' 'db/password')"
  if [[ "${password}" == "" ]]; then
    password="$(generate_16hex)"
  fi
  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_keitaro_password' "${password}"
}


updates.early.since_2_43_9.migrate_inventory.mariadb_system_entries() {
  local path_to_inventory_env="${1}" value password

  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_system_database' 'mysql'

  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_system_user'     'root'

  password="$(updates.early.since_2_43_9.gather_value 'db_root_password')"
  if [[ "${password}" == "" ]] && [[ -f "${ROOT_PREFIX}/root/.my.cnf" ]]; then
    password="$(updates.early.since_2_43_9.read_config_value "${ROOT_PREFIX}/root/.my.cnf" 'client/password')"
  fi
  if [[ "${password}" == "" ]]; then
    password="$(generate_16hex)"
  fi
  env_files.forced_save_var "${path_to_inventory_env}" 'mariadb_system_password' "${password}"
}

updates.early.since_2_43_9.migrate_inventory.mariadb_entries.detect_storage_engine() {
  local tokudb_file_exists
  tokudb_file_exists="$(find /var/lib/mysql -maxdepth 1 -name '*tokudb' -printf 1 -quit)"

  if [[ "${tokudb_file_exists}" == "1" ]]; then
    echo "tokudb"
  else
    echo "innodb"
  fi
}

updates.early.since_2_43_9.migrate_inventory.tracker_entries() {
  local path_to_inventory_env="${1}" value

  value="$(updates.early.since_2_43_9.gather_value 'options')"
  if [[ "${value}" != "" ]]; then
    env_files.forced_save_var "${path_to_inventory_env}" 'tracker_options' "${value}"
  fi

  value="$(updates.early.since_2_43_9.gather_value 'postback_key')"
  if [[ "${value}" != "" ]]; then
    env_files.forced_save_var "${path_to_inventory_env}" 'tracker_postback_key' "${value}"
  fi

  value="$(updates.early.since_2_43_9.gather_value 'salt')"
  updates.early.since_2_43_9.assert_value_is_set "${value}" "Tracker's salt"
  env_files.forced_save_var "${path_to_inventory_env}" 'tracker_salt' "${value}"

  value="$(updates.early.since_2_43_9.gather_value 'prefix' 'table_prefix' 'db/prefix')"
  updates.early.since_2_43_9.assert_value_is_set "${value}" 'Tables prefix'
  env_files.forced_save_var "${path_to_inventory_env}" 'tracker_tables_prefix' "${value}"
}

updates.early.since_2_43_9.migrate_inventory.redis_entries() {
  local path_to_inventory_env="${1}" value

  env_files.forced_save_var "${path_to_inventory_env}" 'redis_keitaro_database' '1'
  env_files.forced_save_var "${path_to_inventory_env}" 'system_redis_keitaro_database' '1'
}

updates.early.since_2_43_9.read_config_value() {
  local path_to_file="${1}" section_with_parameter="${2}" section parameter value

  if [[ "${section_with_parameter}" =~ / ]]; then
    IFS="/" read -r section parameter <<< "${section_with_parameter}"
    local expression="/^\\[${section}\\]/ { :l /^${parameter}\\s*=/ { s/.*=\\s*//; p; q; }; n; b l;}"
    value="$(sed -nr "${expression}" "${path_to_file}")"
  else
    parameter="${section_with_parameter}"
    value="$(grep -Po "(?<=^${parameter}\\b).*" "${path_to_file}" | awk -F '=' '{print $2}')"
  fi
  value="$(echo "${value}" | head -n1 | strings.squish | unquote)"

  if [[ "${value}" != "" ]]; then
    debug "Got ${section_with_parameter} from ${path_to_file}: '$(strings.mask "${parameter}" "${value}")'"
    echo "${value}"
  fi
}

updates.early.since_2_43_9.assert_value_is_set() {
  local value="${1}" description="${2}"
  if [[ "${value}" == "" ]]; then
    fail "${description} is not set!"
  fi
}


updates.early.since_2_43_9() {
  updates.early.since_2_43_9.update_inventory
  updates.early.since_2_43_9.remove_old_cron_tasks
}

updates.early.since_2_43_9.update_inventory() {
  local ansible_inventory_path
  local path_to_temp_inventory_env="${PATH_TO_INVENTORY_ENV}.tmp"

  if [[ -f "${PATH_TO_INVENTORY_ENV}" ]]; then
    updates.print_checkpoint_info "Inventory is already migrated"
    return
  fi

  ansible_inventory_path="$(gathering.gather_ansible_inventory_path)"

  if [[ "${ansible_inventory_path}" == "" ]]; then
    fail "Couldn't detect inventory file. Is Keitaro installed?"
  fi

  msg="Migrating inventory ${ansible_inventory_path}"; print_with_color "${msg}" 'blue'; debug "${msg}"

  updates.early.since_2_43_9.migrate_inventory "${path_to_temp_inventory_env}"
  updates.early.since_2_43_9.backup_old_inventory_files "${ansible_inventory_path}"
  mv -f "${path_to_temp_inventory_env}" "${PATH_TO_INVENTORY_ENV}"

  msg='Inventory migrated'; print_with_color "${msg}" 'green'; debug "${msg}"
}

updates.early.since_2_43_9.remove_old_cron_tasks() {
  updates.run_update_checkpoint_command 'crontab -ru keitaro || true' 'Removing old tracker updaing cron tasks'
  updates.run_update_checkpoint_command 'pkill -f cron.php || true' 'Terminating runing tracker cron tasks'
}

updates.early.since_2_44_0() {
  components.fix_volumes_permissions 'mariadb'
}

updates.early.since_2_42_1() {
  updates.run_update_checkpoint_command "rm -f /etc/logrotate.d/{redis,mysql}" \
            "Removing old logrotate configs"

  packages.actualize_rpm
}

updates.early.since_2_40_0() {
  updates.early.since_2_40_0.move_nginx_file \
          /etc/nginx/conf.d/vhosts.conf /etc/nginx/conf.d/keitaro.conf

  for old_dir in /etc/ssl/certs /etc/nginx/ssl; do
    for cert_name in dhparam.pem cert.pem privkey.pem; do
      updates.early.since_2_40_0.move_nginx_file \
              "${old_dir}/${cert_name}" "/etc/keitaro/ssl/${cert_name}"
    done
  done

  updates.early.since_2_40_0.remove_old_log_format_from_nginx_configs
}

updates.early.since_2_40_0.move_nginx_file() {
  local path_to_old_file="${1}" path_to_new_file="${2}" old_configs_count cmd msg

  if [[ -f "${path_to_old_file}" ]] && [[ ! -f ${path_to_new_file} ]]; then
    cmd="mkdir -p '${path_to_new_file%/*}'"
    cmd="${cmd} && mv '${path_to_old_file}' '${path_to_new_file}'"

    updates.run_update_checkpoint_command "${cmd}" "Moving ${path_to_old_file} -> ${path_to_new_file}"
  fi

  old_configs_count="$(grep -r -l -F "${path_to_old_file}" /etc/nginx | wc -l)"

  if [[ "${old_configs_count}" != "0" ]]; then
    cmd="grep -r -l -F '${path_to_old_file}' /etc/nginx"
    cmd="${cmd} | xargs -r sed -i 's|${path_to_old_file}|${path_to_new_file}|g'"

    updates.run_update_checkpoint_command "${cmd}" \
            "Changing path ${path_to_old_file} -> ${path_to_new_file} in ${old_configs_count} nginx configs"
  fi
}

updates.early.since_2_40_0.remove_old_log_format_from_nginx_configs() {
  local old_log_format="tracker.status" cmd

  old_configs_count="$(grep -r -l -F "${old_log_format}" /etc/nginx/conf.d | wc -l)"

  if [[ "${old_configs_count}" != "0" ]]; then
    cmd="grep -r -l -F '${old_log_format}' /etc/nginx/conf.d | xargs -r sed -i '/${old_log_format}/d'"

    updates.run_update_checkpoint_command "${cmd}" \
            "Removing old log format ${old_log_format} from ${old_configs_count} nginx configs"
  fi
}

updates.early.since_2_41_10() {
  updates.early.since_2_41_10.remove_packages
  updates.early.since_2_41_10.change_nginx_home
  updates.early.since_2_41_10.remove_repos
  updates.early.since_2_41_10.remove_old_ansible
}

PACKAGES_TO_REMOVE_SINCE_2_41_10=(
  nginx redis clickhouse-server MariaDB-server MariaDB-client MariaDB-tokudb-engine MariaDB-common MariaDB-shared
)

updates.early.since_2_41_10.remove_packages() {
  for package in "${PACKAGES_TO_REMOVE_SINCE_2_41_10[@]}"; do
    if is_package_installed "${package}"; then
      updates.run_update_checkpoint_command "yum erase -y ${package}" "Erasing ${package} package"
    fi
  done
}

updates.early.since_2_41_10.change_nginx_home() {
  local nginx_home
  nginx_home="$( (getent passwd nginx | awk -F: '{print $6}') &>/dev/null || true)"
  if [[ "${nginx_home}" != "/var/cache/nginx" ]]; then
    updates.run_update_checkpoint_command "usermod -d /var/cache/nginx nginx; rm -rf /home/nginx" "Changing nginx user home"
  fi
}

updates.early.since_2_41_10.remove_repos() {
  if [ -f /etc/yum.repos.d/mariadb.repo ]; then
    updates.run_update_checkpoint_command "rm -f /etc/yum.repos.d/mariadb.repo" "Removing mariadb repo"
  fi
  if [ -f /etc/yum.repos.d/Altinity-ClickHouse.repo ]; then
    updates.run_update_checkpoint_command "rm -f /etc/yum.repos.d/Altinity-ClickHouse.repo" "Removing clickhouse repo"
  fi
}

updates.early.since_2_41_10.remove_old_ansible() {
  if [[ "$(get_centos_major_release)" == "7" ]] && [[ -f /usr/bin/ansible-2 ]]; then
    updates.run_update_checkpoint_command "yum erase -y ansible" "Removing old ansible"
  fi
  if [[ "$(get_centos_major_release)" == "8" ]] && is_package_installed "ansible"; then
    updates.run_update_checkpoint_command "yum install -y ansible-core --allowerasing" "Removing old ansible"
  fi
}

updates.early.since_2_43_6() {
  local cmd applied_kctld_version var

  if [[ -f /etc/keitaro/env/components-applied.env ]] && [[ ! -f /etc/keitaro/env/applied.env ]]; then
    local cmd="sed 's/^/APPLIED_/g' /etc/keitaro/env/components-applied.env > /etc/keitaro/env/applied.env"
    updates.run_update_checkpoint_command "${cmd}" "Converting applied components env file"
  fi
}

updates.middle.since_2_40_6() {
  updates.middle.since_2_40_6.clean_ch_logs
}

updates.middle.since_2_40_6.clean_ch_logs() {
  local tables_sql

  tables_sql="${tables_sql} SELECT DISTINCT table"
  tables_sql="${tables_sql} FROM system.parts"
  tables_sql="${tables_sql} WHERE active"
  tables_sql="${tables_sql}   AND (table ILIKE '%_log' OR table ILIKE '%_log_%')"
  tables_sql="${tables_sql}   AND database='system'"
  tables="$(kctl run system-clickhouse-query "${tables_sql}")"

  for table in ${tables}; do
    local cmd; cmd="kctl run system-clickhouse-query 'TRUNCATE TABLE $table'"
    updates.run_update_checkpoint_command "${cmd}" "Cleaning CH log table ${table}"
  done
}

updates.middle.since_2_27_0() {
  updates.middle.since_2_27_0.remove_files
  updates.middle.since_2_27_0.disable_firewall
}

updates.middle.since_2_27_0.remove_files() {
  local cmd="rm -rf"
  cmd="${cmd} /var/log/mariadb"
  cmd="${cmd} /etc/keitaro/roadrunner.yml"
  cmd="${cmd} /etc/logrotate.d/mariadb"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-error_log.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-log_slow_queries.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-set_default_storage_engine.cnf"
  cmd="${cmd} /etc/my.cnf.d/mysqld-error_log.cnf"
  cmd="${cmd} /etc/my.cnf.d/mysqld-log_slow_queries.cnf"
  cmd="${cmd} /etc/my.cnf.d/mysqld-optimize_performance.cnf"
  cmd="${cmd} /etc/my.cnf.d/mysqld-set_pidfile_path.cnf"
  cmd="${cmd} /etc/my.cnf.d/mysqld.cnf"
  cmd="${cmd} /etc/my.cnf.d/network.cnf"
  cmd="${cmd} /etc/nginx/conf.d/vhosts.conf"
  cmd="${cmd} /etc/nginx/ssl/cert.pem"
  cmd="${cmd} /etc/nginx/ssl/privkey.pem"
  cmd="${cmd} /etc/ssl/certs/dhparam.pem"
  cmd="${cmd} /etc/sudoers.d/10-enable-ssl-command"
  cmd="${cmd} /opt/eff.org/certbot"
  cmd="${cmd} /root/add-site.log"
  cmd="${cmd} /root/enable-ssl.log"
  cmd="${cmd} /root/hosts.txt"
  cmd="${cmd} /root/install.log"
  cmd="${cmd} /usr/bin/kctl-add-site"
  cmd="${cmd} /usr/bin/kctl-disable-ssl"
  cmd="${cmd} /usr/bin/kctl-enable-ssl"
  cmd="${cmd} /usr/bin/kctl-fail2ban"
  cmd="${cmd} /usr/bin/kctl-install"
  cmd="${cmd} /usr/bin/kctl-prune-ssl"
  cmd="${cmd} /usr/local/bin/certbot"
  cmd="${cmd} /var/www/keitaro/install.php"

  updates.run_update_checkpoint_command "${cmd}" "Removing unneeded files"
}

updates.middle.since_2_27_0.disable_firewall() {
  if [[ -f /etc/systemd/system/firewall.service ]]; then
    local cmd="systemctl stop firewall"
    cmd="${cmd} && systemctl disable firewall"
    cmd="${cmd} && rm -f /etc/systemd/system/firewall.service"
    cmd="${cmd} && systemctl daemon-reload"
    updates.run_update_checkpoint_command "${cmd}" "Disable old firewall service"
  fi
}

updates.middle.since_2_30_0() {
  updates.middle.since_2_30_0.remove_packages
  updates.middle.since_2_30_0.remove_files
}

updates.middle.since_2_30_0.remove_packages() {
  local cmd="yum erase -y sendmail sendmail-cf ntp certbot"
  updates.run_update_checkpoint_command "${cmd}" "Removing unneeded packages"
}

updates.middle.since_2_30_0.remove_files() {
  local cmd="rm -f"
  cmd="${cmd} /etc/firewall.bash"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/tracker.roadrunner.inc"
  cmd="${cmd} /etc/php/roadrunner.yml"
  cmd="${cmd} /etc/yum.repos.d/mariadb-mirror.repo"
  cmd="${cmd} /usr/local/bin/keitaro-generate_stats_json"
  cmd="${cmd} /usr/local/bin/keitaro-print_stats_json"
  cmd="${cmd} /usr/local/bin/keitaro-rotate_nginx_status_logs"
  cmd="${cmd} /var/log/mysql/slow_queries.log"
  cmd="${cmd} && find /var/www/keitaro/var/ -maxdepth 1 -type f -name '*.tmp' -delete"
  updates.run_update_checkpoint_command "${cmd}" "Removing unneeded files"
}

updates.middle.since_2_43_9() {
  local tracker_root; tracker_root="$(components.build_path_to_preinstalled_directory "${TRACKER_COMPONENT}")/www"

  updates.middle.since_2_43_9.create_clickhouse_db_if_need "${tracker_root}"
  updates.middle.since_2_43_9.create_clickhouse_schema_if_need "${tracker_root}"
  updates.middle.since_2_43_9.clean_preinstalled_tracker "${tracker_root}"
}

updates.middle.since_2_43_9.create_clickhouse_db_if_need() {
  local tracker_root="${1}" database_exists
  
  local sql='EXISTS DATABASE keitaro'
  if ! database_exists="$(LOG_PATH=/dev/null ${KCTL_BIN_DIR}/kctl run system-clickhouse-query "${sql}")"; then
    fail "Couldn't check if ClickHouse Keitaro DB exists"
  fi

  if [[ "${database_exists}" == "0" ]]; then
    updates.middle.since_2_43_9.prepare_preinstalled_tracker "${tracker_root}"

    local cmd="LOG_PATH=/dev/null ${KCTL_BIN_DIR}/kctl run system-clickhouse-query 'CREATE DATABASE keitaro'"
    updates.run_update_checkpoint_command "${cmd}" "Creating ClickHouse Keitaro Database"
  fi
}

updates.middle.since_2_43_9.create_clickhouse_schema_if_need() {
  local tracker_root="${1}" schema_exists

  local sql="EXISTS TABLE schema_migrations"
  if ! schema_exists="$(LOG_PATH=/dev/null ${KCTL_BIN_DIR}/kctl run clickhouse-query "${sql}")"; then
    fail "Couldn't check if schema exists in the ClickHouse Keitaro DB"
  fi

  if [[ "${schema_exists}" == "0" ]]; then
    updates.middle.since_2_43_9.prepare_preinstalled_tracker "${tracker_root}"

    local config_ini_path="./application/config/config.ini.php"
    local cmd="LOG_PATH=/dev/null TRACKER_ROOT=${tracker_root} kctl run cli-php ch_db:setup --config ${config_ini_path}"
    updates.run_update_checkpoint_command "${cmd}" "Creating schema in the ClickHouse Keitaro Database"
  fi
}

updates.middle.since_2_43_9.prepare_preinstalled_tracker() {
  local tracker_root="${1}"

  if [[ ! -d ${tracker_root}/var/cache ]]; then
    local cmd="mkdir -p ${tracker_root}/var/{cache,log} && chown keitaro:keitaro -R ${tracker_root}/var"
    updates.run_update_checkpoint_command "${cmd}" "Preparing preinstalled tracker to allow to run cli commands"
  fi
}

updates.middle.since_2_43_9.clean_preinstalled_tracker() {
  local tracker_root="${1}"

  if [[ -d ${tracker_root}/var/cache ]]; then
    local cmd="rm -rf ${tracker_root}/var/{cache,log}"
    updates.run_update_checkpoint_command "${cmd}" "Cleaning preinstalled tracker cache & logs"
  fi
}

updates.middle.since_2_41_10() {
  updates.middle.since_2_41_10.remove_packages
  updates.middle.since_2_41_10.change_nginx_home
  updates.middle.since_2_41_10.remove_repos
  updates.middle.since_2_41_10.remove_old_ansible
}

updates.middle.since_2_41_10.remove_packages() {
  local packages_to_remove=(
    nginx redis clickhouse-server MariaDB-server MariaDB-client MariaDB-tokudb-engine MariaDB-common MariaDB-shared
  )

  for package in "${packages_to_remove[@]}"; do
    if is_package_installed "${package}"; then
      updates.run_update_checkpoint_command "yum erase -y ${package}" "Erasing ${package} package"
    fi
  done
}

updates.middle.since_2_41_10.change_nginx_home() {
  local nginx_home
  nginx_home="$( (getent passwd nginx | awk -F: '{print $6}') &>/dev/null || true)"
  if [[ "${nginx_home}" != "/var/cache/nginx" ]]; then
    updates.run_update_checkpoint_command "usermod -d /var/cache/nginx nginx; rm -rf /home/nginx" "Changing nginx user home"
  fi
}

updates.middle.since_2_41_10.remove_repos() {
  if [ -f /etc/yum.repos.d/mariadb.repo ]; then
    updates.run_update_checkpoint_command "rm -f /etc/yum.repos.d/mariadb.repo" "Removing mariadb repo"
  fi
  if [ -f /etc/yum.repos.d/Altinity-ClickHouse.repo ]; then
    updates.run_update_checkpoint_command "rm -f /etc/yum.repos.d/Altinity-ClickHouse.repo" "Removing clickhouse repo"
  fi
}

updates.middle.since_2_41_10.remove_old_ansible() {
  if [[ "$(get_centos_major_release)" == "7" ]] && [[ -f /usr/bin/ansible-2 ]]; then
    updates.run_update_checkpoint_command "yum erase -y ansible" "Removing old ansible"
  fi
  if [[ "$(get_centos_major_release)" == "8" ]] && is_package_installed "ansible"; then
    updates.run_update_checkpoint_command "yum install -y ansible-core --allowerasing" "Removing old ansible"
  fi
}

updates.middle.since_2_42_5() {
  system.users.create "${KEITARO_SUPPORT_USER}" "${KEITARO_SUPPORT_HOME_DIR}"
}

updates.middle.since_2_39_16() {
  if is_ci_mode; then
    return
  fi
  updates.middle.since_2_39_16.enable_ipv6_in_nginx
  updates.middle.since_2_39_16.remove_cron_tasks
  updates.middle.since_2_39_16.remove_old_files
  updates.middle.since_2_39_16.fix_nginx_configs
}

updates.middle.since_2_39_16.enable_ipv6_in_nginx() {
  local cmd="find /etc/nginx/conf.d -mindepth 1 -maxdepth 1 -type f -name *.conf"
  cmd="${cmd} | xargs --max-args=1000 --no-run-if-empty sed -i 's/listen \\[::]:443;/listen [::]:443 ssl;/g'"
  if grep -LF '[::]' /etc/nginx/conf.d/*.conf | xargs grep -qP '^#.*Keitaro'; then
    cmd="${cmd} && grep -LF '[::]' /etc/nginx/conf.d/*.conf"
    cmd="${cmd} | xargs grep -lP '^#.*Keitaro'"
    cmd="${cmd} | xargs sed -i -r -e '/listen 80/a \  listen [::]:80;' -e '/listen 443/a \  listen [::]:443 ssl;'"
  fi
  updates.run_update_checkpoint_command "${cmd}" "Enable ipv6 in nginx"
}

updates.middle.since_2_39_16.remove_cron_tasks() {
  local cmd="crontab -r -u nginx || true"
  if [[ -f /var/spool/cron/root ]]; then
    cmd="${cmd}; sed -r -i '/(cron.php|certbot)/d' /var/spool/cron/root"
    cmd="${cmd}; sed -i '/\\/usr\\/local\\/bin\\/keitaro-/d' /var/spool/cron/root"
  fi
  updates.run_update_checkpoint_command "${cmd}" "Removing old cron tasks"
}

updates.middle.since_2_39_16.remove_old_files() {
  local cmd="rm -f"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-configure_network.cnf"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/admin.inc"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/locations-common.inc"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/locations-tracker.inc"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/nontracker.inc"
  cmd="${cmd} /etc/nginx/conf.d/keitaro/nontracker.php-fpm.inc"
  cmd="${cmd} /etc/opt/remi/php74/php-fpm.d/keitaro-nontracker.conf"
  cmd="${cmd} /etc/yum.repos.d/docker-ce.repo"
  cmd="${cmd} /etc/yum.repos.d/mariadb-mirror.repo"
  cmd="${cmd} /opt/keitaro/bin/kctl-prune-ssl"
  cmd="${cmd} /usr/local/bin/kctl-prune-ssl"
  cmd="${cmd} /usr/local/bin/keitaro-generate_cf_ip_lists"
  cmd="${cmd} /usr/local/bin/keitaro-generate_stats_json"
  cmd="${cmd} /usr/local/bin/keitaro-print_stats_json"
  cmd="${cmd} /usr/local/bin/keitaro-rotate_nginx_status_logs"
  cmd="${cmd} /var/log/mysql/slow_queries.log"

  cmd="${cmd} && find /var/www/keitaro/var/ -maxdepth 1 -type f -name '*.tmp' -delete"
  updates.run_update_checkpoint_command "${cmd}" "Removing unneeded files"
}


updates.middle.since_2_39_16.fix_nginx_configs() {
  if grep -q 'locations-common' /etc/nginx/conf.d/*.conf; then
    local cmd="grep -l 'locations-common' /etc/nginx/conf.d/*.conf | xargs --max-args=1000 sed -i -r"
    cmd="${cmd} -e '/locations-common/a \\  include /etc/nginx/conf.d/keitaro/locations/1-common.inc;'"
    cmd="${cmd} -e '/locations-common/a \\  include /etc/nginx/conf.d/keitaro/locations/2-www.inc;'"
    cmd="${cmd} -e '/locations-common/a \\  include /etc/nginx/conf.d/keitaro/locations/3-admin.inc;'"
    cmd="${cmd} -e '/locations-common/a \\  include /etc/nginx/conf.d/keitaro/locations/4-tracker.inc;'"
    cmd="${cmd} -e '/locations-common/d'"
    cmd="${cmd} -e '/locations-tracker/d'"
    updates.run_update_checkpoint_command "${cmd}" "Upgrading nginx configs"
  fi
}

updates.post.since_2_41_7() {
  updates.post.since_2_41_7.fix_ch_ttl
  updates.post.since_2_41_7.remove_manage_thp
}

updates.post.since_2_41_7.remove_manage_thp() {
  if [[ -f /sbin/manage-thp ]]; then
    updates.run_update_checkpoint_command 'rm -f /sbin/manage-thp' 'Removing manage-thp'
  fi
}

updates.post.since_2_41_7.fix_ch_ttl() {
  local olap_db db_ttl ch_ttl

  if is_ci_mode; then
    return
  fi

  olap_db="$(inventory.read_var 'olap_db')"
  debug "Current OLAP_DB is ${olap_db}"

  if [[ "${olap_db}" == "${OLAP_DB_CLICKHOUSE}" ]]; then
    updates.print_checkpoint_info "Current OLAP DB is ${olap_db}, changing TTL in CH tables"

    if ! db_ttl="$(LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run cli-php system:get_setting 'stats_ttl')"; then
      fail "Could not detect correct MariaDB ttl"
    fi
    if [[ "${db_ttl}" == "" ]] || [[ ! "${db_ttl}" =~ ^[0-9]+$ ]]; then
      fail "Detected MariaDB ttl is incorrect - '${db_ttl}'"
    fi
    ch_ttl="$(updates.post.since_2_41_7.get_ch_ttl)"
    if [[ "${ch_ttl}" == "" ]] || [[ ! "${ch_ttl}" =~ ^[0-9]+$ ]]; then
      fail "Could not detect correct MariaDB ttl. Detected value is '${ch_ttl}'"
    fi
    if [[ "${db_ttl}" != "${ch_ttl}" ]]; then
      updates.post.since_2_41_7.set_ch_table_ttl "keitaro_clicks" "datetime" "${db_ttl}"
      updates.post.since_2_41_7.set_ch_table_ttl "keitaro_conversions" "postback_datetime" "${db_ttl}"
    else
      updates.print_checkpoint_info "Skip changing CH TTL - it is already set to ${ch_ttl}"
    fi
  else
    updates.print_checkpoint_info "Current OLAP DB is ${olap_db}, skip changing TTL in CH"
  fi
}

updates.post.since_2_41_7.get_ch_ttl() {
  local table_sql ch_tt show_table_query='show create table keitaro_clicks'

  table_sql="$(LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run clickhouse-query "${show_table_query}")"

  if [[ "${table_sql}" != "" ]]; then
    ch_ttl="$(echo -e "${table_sql}" | grep -oP '(?<=TTL datetime \+ toIntervalDay\()[0-9]+')"
    if [[ "${ch_ttl}" == "" ]]; then
      ch_ttl="0"
    fi
    echo "${ch_ttl}"
  fi
}

updates.post.since_2_41_7.set_ch_table_ttl() {
  local table="${1}" datetime_field="${2}" ttl="${3}" sql msg

  if [[ "${ttl}" == "0" ]]; then
    sql="ALTER TABLE ${table} REMOVE TTL"
    msg="Removing TTL from ClickHouse table ${table}"
  else
    sql="ALTER TABLE ${table} MODIFY TTL ${datetime_field} + toIntervalDay(${ttl})"
    msg="Setting TTL for ClickHouse table ${table}"
  fi

  updates.run_update_checkpoint_command "LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run clickhouse-query '${sql}'" "${msg}"
}

updates.post.since_2_44_1() {
  updates.post.since_2_44_1.remove_old_files

  stage5.disable_selinux
  stage5.disable_fastestmirror
  stage5.clean_packages_metadata

  systemd.enable_and_start_service 'podman'
  systemd.enable_and_start_service 'logrotate.timer'
}

updates.post.since_2_44_1.remove_old_files() {
  local file='/etc/systemd/system/roadrunner.service.d/opened-files-limit.conf.j2'
  if [[ -f "${file}" ]]; then
    updates.run_update_checkpoint_command "rm -f ${file}" "Remove wrong RR config"
  fi
}

updates.post.since_1_20_0() {
  updates.post.since_1_20_0.remove_old_nginx_files
  updates.post.since_1_20_0.regenerate_nginx_domain_configs
}

updates.post.since_1_20_0.regenerate_nginx_domain_configs() {
  local old_domains
  # shellcheck disable=SC2038
  old_domains="$(find /etc/nginx/conf.d/ -mindepth 1 -maxdepth 1 -name '*.conf' | \
                 xargs grep -l /var/www/keitaro | \
                 xargs grep -LF 'Generated by Keitaro install tool v2.' | \
                 grep -vP '/(keitaro|vhosts|default).conf' | \
                 sed -r 's|^/etc/nginx/conf.d/(.*).conf$|\1|g' | \
                 tr "\n" " ")"
  if [[ "${old_domains}" != "" ]]; then
    local cmd="KCLTD_MODE=true kctl certificates issue ${old_domains}"
    updates.run_update_checkpoint_command "${cmd}" 'Regenerate old domain configs'
    systemd.reload_service "nginx"
  fi
}

updates.post.since_1_20_0.remove_old_nginx_files() {
  local cmd="rm -rf /etc/nginx/conf.d/keitaro/local"
  cmd="${cmd} && find /etc/nginx/conf.d/keitaro -name '*.local.inc' -or -name 'tracker.*' -delete"
  cmd="${cmd} && find /etc/nginx/conf.d -maxdepth 1 -name '*.conf.20*' -or -name '*.inc' -delete"
  updates.run_update_checkpoint_command "${cmd}" 'Removing old nginx files'
}

updates.post.always_run() {
  updates.post.always_run.fix_tracker_files_permissions
  updates.post.always_run.remove_old_kctl
}

updates.post.always_run.fix_tracker_files_permissions() {
  components.fix_volumes_permissions 'tracker'
}

updates.post.always_run.remove_old_kctl() {
  local path_to_kctl cmd
  path_to_kctl="$(components.build_path_to_preinstalled_directory 'kctl')"
  cmd="find ${KCTL_LIB_PATH}/kctl -mindepth 2 -not -path '${path_to_kctl}/*' -not -path '${path_to_kctl}' -delete"

  updates.run_update_checkpoint_command "${cmd}" "Remove old kctl files"
}

updates.post.since_2_43_9() {
  updates.post.since_2_43_9.remove_old_files
}

updates.post.since_2_43_9.remove_old_files() {
  local cmd="rm -f /etc/keitaro/config/components.env /etc/keitaro/config/components.local.env"
  cmd="${cmd} && rm -f /etc/keitaro/env/system.env"
  cmd="${cmd} && rm -f /etc/keitaro/config/kctl-monitor.env"
  cmd="${cmd} && rm -f /etc/keitaro/config/kctld.env"

  updates.run_update_checkpoint_command "${cmd}" "Remove old env files"
}

updates.post.since_2_45_3() {
  systemd.restart_service 'nginx'
  components.fix_volumes_permissions 'nginx'
}

updates.post.since_2_40_0() {
  updates.post.since_2_40_0.remove_old_files
  updates.post.since_2_40_0.schedule_certificate_renew
}

updates.post.since_2_40_0.remove_old_files() {
  local cmd="rm -rf"
  cmd="${cmd} /etc/clickhouse-server"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-configure_error_log.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-configure_network.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-optimize_performance.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqld-set_default_storage_engine.cnf"
  cmd="${cmd} /etc/my.cnf.d/keitaro-mysqldump-disable_column_statistics.cnf"
  cmd="${cmd} /etc/php/php-fpm.d/keitaro-tracker.conf.disabled"
  cmd="${cmd} /etc/systemd/system/mysql.service.d"
  cmd="${cmd} /etc/systemd/system/nginx.service.d"
  cmd="${cmd} /etc/systemd/system/redis.service.d"
  cmd="${cmd} /var/log/clickhouse"
  cmd="${cmd} /var/log/clickhouse-server"
  cmd="${cmd} /var/log/nginx/tracker.status"
  cmd="${cmd} /var/log/nginx/tracker.status.snapshot"
  cmd="${cmd} /var/run/php74-php-fpm-admin.sock"
  cmd="${cmd} /var/run/php74-php-fpm-nontracker.sock"
  cmd="${cmd} /var/run/php74-php-fpm-www.sock"

  updates.run_update_checkpoint_command "${cmd}" 'Removing old CH files'
}

updates.post.since_2_40_0.schedule_certificate_renew() {
  local cmd
  cmd="pkill certboti || true"
  cmd="${cmd}; ${KCTL_BIN_DIR}/kctl certificates prune safe"
  cmd="${cmd}; nohup ${KCTL_BIN_DIR}/kctl certificates renew &>/dev/null &"

  updates.run_update_checkpoint_command "${cmd}" 'Scheduling LE certificates renew'
}

updates.post.since_2_41_10() {
  rm -f /etc/keitaro/config/nginx.env
  find /var/www/keitaro/var/ -maxdepth 1 -type f -name 'stats.json-*.tmp' -delete || true
}

updates.post.since_2_44_3() {
  updates.post.since_2_44_3.create_certbot_renew_volumes
  updates.post.since_2_44_3.remove_old_cron_tasks
  updates.post.since_2_44_3.remove_old_kctl_configs
}

updates.post.since_2_44_3.create_certbot_renew_volumes() {
  components.create_volumes 'certbot'
  updates.print_checkpoint_info 'Created certbot volumes'
}

updates.post.since_2_44_3.remove_old_cron_tasks() {
  local cmd='rm -f'
  cmd="${cmd} /etc/cron.daily/kctl-certificates-renew"
  cmd="${cmd} /etc/cron.d/restart-died-kctld-worker"
  cmd="${cmd} /etc/cron.d/keitaro-traffic-log-trimmer"
  updates.run_update_checkpoint_command "${cmd}" "Removing old cron tasks"
}

updates.post.since_2_44_3.remove_old_kctl_configs() {
  local cmd='rm -f'
  cmd="${cmd} /etc/keitaro/config/{tracker.env,inventory}"
  cmd="${cmd} /etc/keitaro/env/system.env"
  updates.run_update_checkpoint_command "${cmd}" "Removing old kctl configs"
}

updates.post.since_2_42_8() {
  local cmd

  cmd="(LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl podman stop certbot || true)"
  cmd="${cmd} && (LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl podman prune certbot || true)"
  updates.run_update_checkpoint_command "${cmd}" "Prune certbot containers"

  systemd.restart_service 'tracker-maintain-certificates'
}

UPDATE_FN_PREFIX="updates"
UPDATE_FN_SUFFIX="since"

updates.run() {
  local stage="${1}"
  local update_fn_prefix="${UPDATE_FN_PREFIX}.${stage}.${UPDATE_FN_SUFFIX}_"
  local always_update_fn="${UPDATE_FN_PREFIX}.${stage}.always_run"
  local applied_kctl_version checkpoint_versions

  if ! { is_running_in_update_mode || is_running_in_repair_mode; }; then
    return
  fi

  applied_kctl_version="$(components.read_applied_var 'kctl' 'version')"

  checkpoint_versions="$(updates.list_checkpoint_versions "${update_fn_prefix}" "${applied_kctl_version}")"

  if [[ "${checkpoint_versions}" == "" ]] && ! system.is_fn_defined "${always_update_fn}"; then
    msg="No ${stage} update checkpoints found to evaluate while updating Keitaro from v${applied_kctl_version}"
    debug "${msg}" && print_with_color "  ${msg}" 'blue'
    return
  fi

  updates.print_updating_message "${stage}" "${applied_kctl_version}"

  updates.run_checkpoints "${update_fn_prefix}" "${stage}" "${applied_kctl_version}" "${checkpoint_versions}"
  if system.is_fn_defined "${always_update_fn}"; then
    updates.run_checkpoint "${always_update_fn}" "${stage}" "'always run'"
  fi
}

updates.run_checkpoints() {
  local update_fn_prefix="${1}" stage="${2}" applied_kctl_version="${3}" checkpoint_versions="${4}"

  for checkpoint_version in ${checkpoint_versions}; do
    local version_str; version_str="$(versions.patch "${checkpoint_version}")"
    local update_fn_name="${update_fn_prefix}${version_str//./_}"

    updates.run_checkpoint "${update_fn_name}" "${stage}" "since v${version_str}"
  done
}

updates.run_checkpoint() {
  local update_fn_name="${1}" stage="${2}"  version_description="${3}"

  local msg="Evaluating ${stage} update checkpoint ${version_description}"
  print_with_color "${msg}" 'blue' && debug "${msg}"

  if "${update_fn_name}"; then
    local msg="Successfully evaluated ${stage} update checkpoint ${version_description}"
    print_with_color "${msg}" 'green'; debug "${msg}"
  else
    fail "Unexpected error while evaluating ${stage} update checkpoint ${version_description}"
  fi
}

updates.print_updating_message() {
  local stage="${1}" applied_kctl_version="${2}"
  local kctl_version msg from_to_msg

  kctl_version="$(components.read_var 'kctl' 'version')"

  msg="Updating Keitaro"

  if [[ "${applied_kctl_version}" != "" ]]; then
    from_to_msg="${msg} from v${applied_kctl_version}"
  fi
  if [[ "${kctl_version}" != "" ]]; then
    from_to_msg="to v${kctl_version}"
  fi

  msg="Updating Keitaro ${from_to_msg} - run ${stage} update checkpoints:"
  print_with_color "${msg}" 'blue' && debug "${msg}"
}

updates.list_checkpoint_versions() {
  local update_fn_prefix="${1}" applied_kctl_version="${2}"

  updates.list_checkpoint_versions_unsorted "${update_fn_prefix}" "${applied_kctl_version}" | versions.sort
}

updates.list_checkpoint_versions_unsorted() {
  local update_fn_prefix="${1}" applied_kctl_version="${2}"
  local checkpoint_versions update_fns

  for update_fn in $(updates.list_update_fns "${update_fn_prefix}"); do
    checkpoint_version="$(updates.extract_checkpoint_version "${update_fn_prefix}" "${update_fn}")"
    if versions.lte "${applied_kctl_version}" "${checkpoint_version}"; then
      echo "${checkpoint_version}"
    fi
  done
}

system.is_fn_defined() {
  local fn="${1}"
  system.list_defined_fns | grep -P "^${fn//./\\.}$" > /dev/null
}

updates.list_update_fns() {
  local update_fn_prefix="${1}"
  system.list_defined_fns | grep -P "^${update_fn_prefix//./\\.}[^\\.]+$"
}

updates.extract_checkpoint_version() {
  local update_fn_prefix="${1}" update_fn="${2}"
  local update_fn_prefix_length="${#update_fn_prefix}"
  local version_str="${update_fn:${update_fn_prefix_length}}"

  echo "${version_str//_/.}"
}

updates.run_update_checkpoint_command() {
  local cmd="${1}" msg="${2}"

  run_command "${cmd}" "  ${msg}" 'hide_output'
}

updates.print_checkpoint_info() {
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
  stage0 "$@"               # initial script setup
  stage1                    # make some asserts
  stage2                    # early update steps
  stage3                    # install & run actual kctl
  stage4                    # read & generate necessary env files
  pushd "${TMPDIR}" &> /dev/null
  stage5                    # install kctl* scripts and related packages
  stage6                    # middle update steps
  stage7                    # run ansible playbook
  stage8                    # post update steps
  stage9                    # update packages
  popd &> /dev/null || true
}

main "$@"
