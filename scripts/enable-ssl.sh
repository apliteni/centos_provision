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

TOOL_NAME='enable-ssl'

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

declare -a DOMAINS
declare -a SUCCESSFUL_DOMAINS
declare -a FAILED_DOMAINS
SSL_ROOT="/etc/keitaro/ssl"
SSL_CERT_PATH="${SSL_ROOT}/cert.pem"
SSL_PRIVKEY_PATH="${SSL_ROOT}/privkey.pem"
CERT_DOMAINS_PATH="${WORKING_DIR}/ssl_enabler_cert_domains"
CERTBOT_LOG="${WORKING_DIR}/ssl_enabler_cerbot.log"
CERTBOT_LOCK_FILE="/var/lib/letsencrypt/.certbot.lock"
SSL_ENABLER_ERRORS_LOG="${WORKING_DIR}/ssl_enabler_errors.log"
FORCE_ISSUING_CERTS="${FORCE_ISSUING_CERTS:-}"

if isset "${KCTLD_MODE}"; then
  FORCE_ISSUING_CERTS='true'
fi
DICT['en.prompts.ssl_domains']='Please enter domains separated by comma without spaces'
DICT['en.prompts.ssl_domains.help']='Make sure all the domains are already linked to this server in the DNS'
DICT['en.errors.domain_invalid']=":domain: doesn't look as valid domain"
DICT['en.certbot_errors.wrong_a_entry']="Please make sure that your domain name was entered correctly and the DNS A record for that domain contains the right IP address. You need to wait a little if the DNS A record was updated recently."
DICT['en.certbot_errors.too_many_requests']="There were too many requests. See https://letsencrypt.org/docs/rate-limits/."
DICT['en.certbot_errors.fetching']="There was connection error while issuing certificate. Try running the script again in an hour. If the error persists, contact support."
DICT['en.certbot_errors.unknown_error']="There was unknown error while issuing certificate, please contact support team"
DICT['en.errors.already_running']="Another certificate issue process is running."

DICT['en.messages.make_ssl_cert_links']="Make SSL certificate links"
DICT['en.messages.requesting_certificate_for']="Requesting certificate for"
DICT['en.messages.ssl_enabled_for_domains']="SSL certificates are issued for domains:"
DICT['en.messages.ssl_not_enabled_for_domains']="There were errors while issuing certificates for domains:"
DICT['en.warnings.nginx_config_exists_for_domain']="nginx config already exists"
DICT['en.warnings.certificate_exists_for_domain']="certificate already exists"
DICT['en.warnings.skip_nginx_config_generation']="skipping nginx config generation"
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

build_certbot_command() {
  echo "LOG_PATH=/dev/stderr ${KCTL_BIN_DIR}/kctl run certbot"
}

certbot.register_account() {
  local cmd
  cmd="$(build_certbot_command) register"
  cmd="${cmd} --agree-tos --non-interactive --register-unsafely-without-email"

  run_command "${cmd}" "Creating certbot account" "hide_output"
}

get_centos_major_release() {
  grep -oP '(?<=release )\d+' /etc/centos-release
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


stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
}


parse_options(){
  while getopts ":D:fhvL:l:wr" option; do
    argument="${OPTARG}"
    case "${option}" in
      D)
        VARS['ssl_domains']="${argument}"
        ensure_valid D ssl_domains validate_domains_list
        ;;
      f)
        FORCE_ISSUING_CERTS="true"
        ;;
      w)
        KCTLD_MODE="true"
        ;;
      r)
        LOG_PATH="/dev/stderr"
        ;;
      *)
        common_parse_options "${option}" "${argument}"
        ;;
    esac
  done
  ensure_options_correct
  get_domains_from_arguments "${@}"
}


get_domains_from_arguments(){
  shift $((OPTIND-1))
  if [[ ${#} == 0 ]]; then
    return
  fi
  while [[ ${#} -gt 0 ]]; do
    if validate_domain "$1"; then
      DOMAINS+=("$(to_lower "${1}")")
    else
      fail "$1 - invalid domain"
    fi
    shift
  done
  VARS['ssl_domains']="$(join_by "," "${DOMAINS[@]}")"
}



help_en(){
  print_err "$SCRIPT_NAME issues Let's Encrypt SSL certificate and generates nginx configuration"
  print_err "The use of this program implies acceptance of the terms of the Let's Encrypt Subscriber Agreement."
  print_err "Example: $SCRIPT_NAME -D domain1.tld,domain2.tld"
  print_err
  print_err "Script automation:"
  print_err "  -f                       force issuing certs (disable compatility check)."
  print_err "  -w                       without reload nginx."
  print_err "  -r                       display certbot result."
  print_err
}

stage2() {
  debug 'Starting stage 2: make some asserts'
  check_assertion 'Same process is not running'
  check_assertion 'Another certbot process is not runing'
}

stage3(){
  debug "Starting stage 3: install LE certificates"
  generate_certificates
  if isset "${SUCCESSFUL_DOMAINS[@]}" && empty "${KCTLD_MODE}" && [[ "${SKIP_RELOADING_NGINX}" == "" ]]; then
    start_or_reload_nginx
  fi
  show_finishing_message
}

generate_certificates() {
  debug "Requesting certificates"
  echo -n > "$SSL_ENABLER_ERRORS_LOG"
  IFS=',' read -r -a domains <<< "${VARS['ssl_domains']}"
  for domain in "${domains[@]}"; do
    generate_certificate_for_domain "${domain}"
  done
  rm -f "${CERT_DOMAINS_PATH}"
}

generate_certificate_for_domain() {
  certificate_generated=${FALSE}
  certificate_error=""
  clear_log_before_certificate_request "${CERTBOT_LOG}"
  initialize_additional_ssl_logging_for_domain "${domain}"
  if [[ "${SKIP_ISSUING_CERTIFICATE}" != "" ]] || actual_certificate_exists_for_domain "$domain"; then
    debug "Actual certificate already exists for domain ${domain}"
    SUCCESSFUL_DOMAINS+=("${domain}")
    print_with_color "${domain}: $(translate 'warnings.certificate_exists_for_domain')" "yellow"
    certificate_generated=${TRUE}
  else
    debug "Actual certificate for domain ${domain} does not exist"
    if request_certificate_for "${domain}"; then
      SUCCESSFUL_DOMAINS+=("${domain}")
      debug "Certificate for domain ${domain} successfully issued"
      certificate_generated=${TRUE}
    else
      FAILED_DOMAINS+=("${domain}")
      debug "There was an error while issuing certificate for domain ${domain}"
      if ! is_logging_to_file; then
        cat "${CERTBOT_LOG}"
      fi
      certificate_error="$(recognize_error "$CERTBOT_LOG")"
      echo "${domain}: ${certificate_error}" >> "$SSL_ENABLER_ERRORS_LOG"
    fi
  fi
  if [[ ${certificate_generated} == "${TRUE}" ]]; then
    debug "Generating nginx config for ${domain}"
    generate_vhost_ssl_enabler "${domain}"
  else
    debug "Skip generation nginx config ${domain} due errors while cert issuing"
    print_with_color "${domain}: ${certificate_error}" "red"
    print_with_color "${domain}: $(translate 'warnings.skip_nginx_config_generation')" "yellow"
  fi
  finalize_additional_ssl_logging_for_domain "${domain}"
}

initialize_additional_ssl_logging_for_domain() {
  if ! is_logging_to_file; then
     return
  fi
  local domain="${1}"
  local additional_log_path
  additional_log_path="$(tmp_ssl_log_path_for_domain "${domain}")"
  echo -n > "${additional_log_path}"
  debug "Start copying logs to ${additional_log_path}"
  ADDITIONAL_LOG_PATH="${additional_log_path}"
}

finalize_additional_ssl_logging_for_domain() {
  if ! is_logging_to_file; then
     return
  fi
  local domain="${1}"
  local additional_log_path="${ADDITIONAL_LOG_PATH}"
  local domain_ssl_log_path
  domain_ssl_log_path="$(ssl_log_path_for_domain "${domain}")"
  debug "Stop copying logs to ${additional_log_path}."
  ADDITIONAL_LOG_PATH=""
  debug "Moving ${additional_log_path} to ${domain_ssl_log_path}"
  if mv "${additional_log_path}" "${domain_ssl_log_path}"; then
    debug "Done"
  else
    fail "errors.unexpected"
  fi
}

actual_certificate_exists_for_domain(){
  local domain="${1}"
  local path_to_certs_dir="/etc/letsencrypt/live/${domain}"
  local path_to_cert="${path_to_certs_dir}/fullchain.pem"""
  directory_exists "/etc/letsencrypt/live/${domain}" && \
    file_exists "${path_to_cert}" && \
    [[ $(date -r "${path_to_cert}" +%s) -gt $(date +%s --date '80 days ago') ]]
}

CERTBOT_PREFERRED_CHAIN="ISRG Root X1"

request_certificate_for(){
  local domain="${1}"
  local certbot_command=""
  debug "Requesting certificate for domain ${domain}"
  certbot_command="$(build_certbot_command) certonly"
  certbot_command="${certbot_command} --webroot --webroot-path=${TRACKER_ROOT}"
  certbot_command="${certbot_command} --agree-tos --non-interactive"
  certbot_command="${certbot_command} --domain ${domain}"
  certbot_command="${certbot_command} --register-unsafely-without-email"
  certbot_command="${certbot_command} --preferred-chain \"${CERTBOT_PREFERRED_CHAIN}\""
  requesting_message="$(translate "messages.requesting_certificate_for") ${domain}"
  run_command "${certbot_command}" "${requesting_message}" "hide_output" "allow_errors" "" "" "$CERTBOT_LOG"
}

ssl_log_path_for_domain() {
  local domain="${1}"
  echo "${SSL_LOG_DIR}/${domain}.log"
}

tmp_ssl_log_path_for_domain() {
  local domain="${1}"
  echo "${SSL_LOG_DIR}/.${domain}.log.tmp"
}

clear_log_before_certificate_request(){
  local log="${1}"
  true > "${log}"
}

generate_vhost(){
  local domain="${1}"
  shift
  debug "Generate vhost by ${TOOL_NAME} for domain $domain"
  local vhost_path
  vhost_path="$(get_vhost_path "$domain")"
  if nginx_vhost_already_processed "$vhost_path"; then
    print_with_color "$(translate 'messages.skip_nginx_conf_generation')" "yellow"
  else
    local commands
    commands="$(get_vhost_generating_commands "${vhost_path}" "${@}")"
    local message
    message="$(translate "messages.generating_nginx_vhost" "domain=${domain}")"
    run_command "$commands" "$message" hide_output
  fi
}

get_vhost_generating_commands(){
  local vhost_path="${1}"
  shift
  declare -a   local commands
  local vhost_override_path
  local vhost_backup_path
  vhost_override_path="$(get_vhost_override_path "$domain")"
  if nginx_vhost_relevant "$vhost_path"; then
    debug "File ${vhost_path} generated by relevant installer tool, skip regenerating"
  else
    debug "File ${vhost_path}, force generating"
    commands+=("/bin/cp -f ${NGINX_KEITARO_CONF} ${vhost_path}")
    commands+=("touch ${vhost_override_path}")
  fi
  sed_expressions="$(nginx_vhost_sed_expressions "${vhost_path}" "${vhost_override_path}" "${@}")"
  commands+=("sed -i ${sed_expressions} ${vhost_path}")
  join_by " && " "${commands[@]}"
}

get_vhost_override_path(){
  local domain="${1}"
  echo "${NGINX_VHOSTS_DIR}/local/${domain}.inc"
}

get_vhost_path(){
  local domain="${1}"
  echo "${NGINX_VHOSTS_DIR}/${domain}.conf"
}

nginx_vhost_sed_expressions(){
  local vhost_path="${1}"
  local vhost_override_path="${2}"
  shift 2
  local expressions=''
  expressions="${expressions} -e '1a# Post-processed by Keitaro ${TOOL_NAME} tool v${RELEASE_VERSION}'"
  if ! file_content_matches "$vhost_path" "-F" "include ${vhost_override_path};"; then
    expressions="${expressions} -e '/server.inc;/a\ \ include ${vhost_override_path};'"
  fi
  expressions="${expressions} -e 's/server_name _/server_name ${domain}/'"
  expressions="${expressions} -e 's/ default_server;/;/'"
  while isset "${1}"; do
    expressions="${expressions} -e '${1}'"
    shift
  done
  echo "$expressions"
}


nginx_vhost_relevant(){
  local vhost_path="${1}"
  file_content_matches "$vhost_path" "-F" "# Generated by Keitaro install tool v${RELEASE_VERSION}"
}


nginx_vhost_already_processed(){
  local vhost_path="${1}"
  file_content_matches "$vhost_path" "-F" "# Post-processed by Keitaro ${TOOL_NAME} tool v${RELEASE_VERSION}"
}

generate_vhost_ssl_enabler() {
  local domain="${1}"
  local certs_root_path="/etc/letsencrypt/live/${domain}"
  generate_vhost "$domain" \
      "s|ssl_certificate .*|ssl_certificate ${certs_root_path}/fullchain.pem;|" \
      "s|ssl_certificate_key .*|ssl_certificate_key ${certs_root_path}/privkey.pem;|"
}


recognize_error() {
  local certbot_log="${1}"
  local key="unknown_error"
  debug "$(print_content_of "${certbot_log}")"
  if is_lets_encrypt_rate_limit_exceeded "${certbot_log}"; then
    key="too_many_requests"
  else
    local error_detail
    error_detail=$(grep '^    Detail:' "${certbot_log}" 2>/dev/null)
    debug "certbot error detail from ${certbot_log}: ${error_detail}"
    if [[ $error_detail =~ "NXDOMAIN looking up A" ]]; then
      key="wrong_a_entry"
    elif [[ $error_detail =~ "No valid IP addresses found" ]]; then
      key="wrong_a_entry"
    elif [[ $error_detail =~ "Invalid response from" ]]; then
      key="wrong_a_entry"
    elif [[ $error_detail =~ "Fetching" ]]; then
      key="fetching"
    fi
  fi
  debug "The error key is ${key}"
  print_translated "certbot_errors.${key}"
}


is_lets_encrypt_rate_limit_exceeded() {
  local certbot_log="${1}"
  grep -q '^There were too many requests' "${certbot_log}" ||
    grep -q ':: too many new orders recently:' "${certbot_log}"
}

show_finishing_message(){
  local color=""
  if isset "${SUCCESSFUL_DOMAINS[@]}" && empty "${FAILED_DOMAINS[@]}"; then
    print_with_color "$(translate 'messages.successful')" 'green'
    print_enabled_domains
  fi
  if isset "${SUCCESSFUL_DOMAINS[@]}" && isset "${FAILED_DOMAINS[@]}"; then
    print_enabled_domains
    print_not_enabled_domains 'yellow'
  fi
  if empty "${SUCCESSFUL_DOMAINS[@]}" && isset "${FAILED_DOMAINS[@]}"; then
    print_not_enabled_domains 'red'
  fi
}


print_enabled_domains(){
  local domains
  message="$(translate 'messages.ssl_enabled_for_domains')"
  domains=$(join_by ", " "${SUCCESSFUL_DOMAINS[@]}")
  print_with_color "OK. ${message} ${domains}" 'green'
}


print_not_enabled_domains(){
  local domains
  local color="${1}"
  message="$(translate 'messages.ssl_not_enabled_for_domains')"
  domains=$(join_by ", " "${FAILED_DOMAINS[@]}")
  print_with_color "NOK. ${message} ${domains}" "${color}"
  print_with_color "$(cat "$SSL_ENABLER_ERRORS_LOG")" "${color}"
}


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html
enable_ssl(){
  init "$@"
  stage1 "$@"
  stage2
  stage3
}

enable_ssl "$@"
