#!/usr/bin/env bash

set -e                                # halt on error
set +m
shopt -s lastpipe                     # flexible while loops (maintain scope)
shopt -s extglob                      # regular expressions

umask 22


SUCCESS_RESULT=0
TRUE=0
FAILURE_RESULT=1
INTERRUPTED_BY_USER_RESULT=130
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

last () {
  [[ -z $1 ]] && return 1;
  eval "${$1[@]:(-1)}"
}

is_ci_mode() {
  [[ "$EUID" != "$ROOT_UID" || "${CI}" != "" ]]
}

is_pipe_mode(){
  [ "${SELF_NAME}" == 'bash' ]
}

TOOL_NAME='enable-ssl'

SELF_NAME=${0}

KEITARO_URL='https://keitaro.io'

RELEASE_VERSION='2.30.8'
VERY_FIRST_VERSION='0.9'
DEFAULT_BRANCH="releases/stable"
BRANCH="${BRANCH:-${DEFAULT_BRANCH}}"

if is_ci_mode; then
  ROOT_PREFIX='.keitaro'
else
  ROOT_PREFIX=''
fi

declare -A VARS
declare -A ARGS
declare -A DETECTED_VARS

WEBAPP_ROOT="${ROOT_PREFIX}/var/www/keitaro"

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
LOG_PATH="${LOG_DIR}/${LOG_FILENAME}"

INVENTORY_DIR="${ETC_DIR}/config"
INVENTORY_PATH="${INVENTORY_DIR}/inventory"
DETECTED_INVENTORY_PATH=""

NGINX_CONFIG_ROOT="/etc/nginx"
NGINX_VHOSTS_DIR="${NGINX_CONFIG_ROOT}/conf.d"
NGINX_KEITARO_CONF="${NGINX_VHOSTS_DIR}/keitaro.conf"

SCRIPT_NAME="kctl-${TOOL_NAME}"

CURRENT_COMMAND_OUTPUT_LOG="${WORKING_DIR}/current_command.output.log"
CURRENT_COMMAND_ERROR_LOG="${WORKING_DIR}/current_command.error.log"
CURRENT_COMMAND_SCRIPT_NAME="current_command.sh"

CERTBOT_PREFERRED_CHAIN="ISRG Root X1"

INDENTATION_LENGTH=2
INDENTATION_SPACES=$(printf "%${INDENTATION_LENGTH}s")

TOOL_ARGS="${*}"
declare -A DICT

DICT['en.errors.program_failed']='PROGRAM FAILED'
DICT['en.errors.must_be_root']='You runs this program as root.'
DICT['en.errors.upgrade_server']='You should upgrade the server configuration. Please contact Keitaro support team.'
DICT['en.errors.run_command.fail']='There was an error evaluating current command'
DICT['en.errors.run_command.fail_extra']=''
DICT['en.errors.terminated']='Terminated by user'
DICT['en.errors.unexpected']='Unexpected error'
DICT['en.errors.cant_upgrade']='Cannot upgrade because installation process is not finished yet'
DICT['en.errors.already_running']="Another installation process is running."
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
FORCE_ISSUING_CERTS=''
DICT['en.prompts.ssl_domains']='Please enter domains separated by comma without spaces'
DICT['en.prompts.ssl_domains.help']='Make sure all the domains are already linked to this server in the DNS'
DICT['en.errors.see_logs']="Evaluating log saved to ${LOG_PATH}."
DICT['en.errors.domain_invalid']=":domain: doesn't look as valid domain"
DICT['en.certbot_errors.wrong_a_entry']="Please make sure that your domain name was entered correctly and the DNS A record for that domain contains the right IP address. You need to wait a little if the DNS A record was updated recently."
DICT['en.certbot_errors.too_many_requests']="There were too many requests. See https://letsencrypt.org/docs/rate-limits/."
DICT['en.certbot_errors.fetching']="There was connection error while issuing certificate. Try running the script again in an hour. If the error persists, contact support."
DICT['en.certbot_errors.unknown_error']="There was unknown error while issuing certificate, please contact support team"
DICT['en.messages.check_renewal_job_scheduled']="Check that the renewal job is scheduled"
DICT['en.messages.make_ssl_cert_links']="Make SSL certificate links"
DICT['en.messages.requesting_certificate_for']="Requesting certificate for"
DICT['en.messages.schedule_renewal_job']="Schedule renewal SSL certificate cron job"
DICT['en.messages.ssl_enabled_for_domains']="SSL certificates are issued for domains:"
DICT['en.messages.ssl_not_enabled_for_domains']="There were errors while issuing certificates for domains:"
DICT['en.warnings.nginx_config_exists_for_domain']="nginx config already exists"
DICT['en.warnings.certificate_exists_for_domain']="certificate already exists"
DICT['en.warnings.skip_nginx_config_generation']="skipping nginx config generation"

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

assert_caller_root(){
  debug 'Ensure script has been running by root'
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
    fail "$(translate "${error}")" "see_logs"
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

file_content_matches(){
  local file="${1}"
  local pattern="${2}"
  debug "Checking ${file} file matching with pattern '${pattern}'"
  if test -f "$file" && grep -q "$pattern" "$file"; then
    debug "YES: ${file} file matches '${pattern}'"
    return ${SUCCESS_RESULT}
  else
    debug "NO: ${file} file does not match '${pattern}"
    return ${FAILURE_RESULT}
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
build_certbot_command() {
  if is_ci_mode; then
    echo "/usr/bin/certbot"
  else
    echo "/usr/bin/docker run --network host --rm -it $(dockerized_certbot_volumes) certbot/certbot"
  fi
}

DOCKERIZED_CERTBOT_VOLUME_PATHS="/etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt /var/www/keitaro"

dockerized_certbot_volumes() {
  local dockerized_certbot_volumes=""
  for volume_path in ${DOCKERIZED_CERTBOT_VOLUME_PATHS}; do
    dockerized_certbot_volumes="${dockerized_certbot_volumes} -v ${volume_path}:${volume_path}"
  done
  echo "${dockerized_certbot_volumes}"
}


# Based on https://stackoverflow.com/a/53400482/612799
#
# Use:
#   (( $(as_version 1.2.3.4) >= $(as_version 1.2.3.3) )) && echo "yes" || echo "no"
#
# Version number should contain from 1 to 4 parts (3 dots) and each part should contain from 1 to 3 digits
#
AS_VERSION__MAX_DIGITS_PER_PART=3
AS_VERSION__PART_REGEX="[[:digit:]]{1,${AS_VERSION__MAX_DIGITS_PER_PART}}"
AS_VERSION__PARTS_TO_KEEP=4
AS_VERSION__REGEX="(${AS_VERSION__PART_REGEX}\.){1,${AS_VERSION__PARTS_TO_KEEP}}"

as_version() {
  local version_string="${1}"
  # Expand version string by adding `.` to the end to simplify logic
  local major_part='0'
  local minor_part='0'
  local patch_part='0'
  local additional_part='0'
  if [[ "${version_string}." =~ ^${AS_VERSION__REGEX}$ ]]; then
    IFS='.' read -r -a parts <<< "${version_string}"
    major_part="${parts[0]:-${major_part}}"
    minor_part="${parts[1]:-${minor_part}}"
    patch_part="${parts[2]:-${patch_part}}"
    additional_part="${parts[3]:-${additional_part}}"
  fi
  printf '1%03d%03d%03d%03d' "${major_part}" "${minor_part}" "${patch_part}" "${additional_part}"
}

as_minor_version() {
  local version_string="${1}"
  local version_number
  version_number=$(as_version "${version_string}")
  local meaningful_version_length=$(( 1 + 2*AS_VERSION__MAX_DIGITS_PER_PART ))
  local zeroes_length=$(( 1 + AS_VERSION__PARTS_TO_KEEP * AS_VERSION__MAX_DIGITS_PER_PART - meaningful_version_length ))
  local meaningful_version=${version_number:0:${meaningful_version_length}}
  printf "%d%0${zeroes_length}d" "${meaningful_version}"
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

is_compatible_with_current_release() {
  [[ "${RELEASE_VERSION}" == "${INSTALLED_VERSION}" ]]
}

run_obsolete_tool_version_if_need() {
  debug 'Ensure configs has been genereated by relevant installer'
  if isset "${FORCE_ISSUING_CERTS}"; then
    debug "Skip checking current version and force isuuing certs"
  elif is_compatible_with_current_release; then
    debug "Current ${RELEASE_VERSION} is compatible with ${INSTALLED_VERSION}"
  else
    local tool_url="${KEITARO_URL}/v${INSTALLED_VERSION}/${TOOL_NAME}.sh"
    local tool_args="${TOOL_ARGS}"
    if (( $(as_version "${INSTALLED_VERSION}") < $(as_version "1.13") )); then
      fail "$(translate 'errors.upgrade_server')"
    fi
    if [[ "${TOOL_NAME}" == "add-site" ]]; then
      tool_args="-D ${VARS['site_domains']} -R ${VARS['site_root']}"
    fi
    if [[ "${TOOL_NAME}" == "enable-ssl" ]]; then
      tool_args="-D ${VARS['ssl_domains']}"
    fi
    command="curl -fsSL ${tool_url} | bash -s -- ${tool_args}"
    run_command "${command}" "Running obsolete ${TOOL_NAME} (v${INSTALLED_VERSION})"
    exit
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

is_installed(){
  local command="${1}"
  debug "Try to find command '$command'"
  if [[ $(sh -c "command -v '$command' -gt /dev/null") ]]; then
    debug "FOUND: Command '$command' found"
  else
    debug "NOT FOUND: Command '$command' not found"
    return ${FAILURE_RESULT}
  fi
}

is_package_installed(){
  local package="${1}"
  debug "Try to find package '$package'"
  if yum list installed --quiet "$package" &> /dev/null; then
    debug "FOUND: Package '$package' found"
  else
    debug "NOT FOUND: Package '$package' not found"
    return ${FAILURE_RESULT}
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
  sed -r "s/^/$INDENTATION_SPACES/g"
}

get_user_var(){
  local var_name="${1}"
  local validation_methods="${2}"
  print_prompt_help "$var_name"
  while true; do
    print_prompt "$var_name"
    value="$(read_stdin)"
    debug "$var_name: got value '${value}'"
    if ! empty "$value"; then
      VARS[$var_name]="${value}"
    fi
    error=$(get_error "${var_name}" "$validation_methods")
    if isset "$error"; then
      debug "$var_name: validation error - '${error}'"
      print_prompt_error "$error"
      VARS[$var_name]=''
    else
      if [[ "$validation_methods" =~ 'validate_yes_no' ]]; then
        transform_to_yes_no "$var_name"
      fi
      debug "  ${var_name}=${VARS[${var_name}]}"
      break
    fi
  done
}
hack_stdin_if_pipe_mode(){
  if is_pipe_mode; then
    debug 'Detected pipe bash mode. Stdin hack enabled'
    hack_stdin
  else
    debug "Can't detect pipe bash mode. Stdin hack disabled"
  fi
}


hack_stdin(){
  exec 3<&1
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
  vhost_backup_path="$(get_vhost_backup_path "$domain")"
  vhost_override_path="$(get_vhost_override_path "$domain")"
  if nginx_vhost_relevant "$vhost_path"; then
    debug "File ${vhost_path} generated by relevant installer tool, skip regenerating"
  else
    if file_exists "$vhost_path"; then
      debug "File ${vhost_path} generated by irrelevant installer tool, force regenerating"
      commands+=("cp ${vhost_path} ${vhost_backup_path}")
    else
      debug "File ${vhost_path} does not exist, force generating"
    fi
    commands+=("cp ${NGINX_KEITARO_CONF} ${vhost_path}")
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


get_vhost_backup_path(){
  local domain="${1}"
  echo "${NGINX_VHOSTS_DIR}/${domain}.conf.$(date +%Y%m%d%H%M%S)"
}


nginx_vhost_sed_expressions(){
  local vhost_path="${1}"
  local vhost_override_path="${2}"
  shift 2
  local expressions=''
  expressions="${expressions} -e '1a# Post-processed by Keitaro ${TOOL_NAME} tool v${RELEASE_VERSION}'"
  if ! file_content_matches "$vhost_path" "include ${vhost_override_path};"; then
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
  file_content_matches "$vhost_path" "# Generated by Keitaro install tool v${RELEASE_VERSION}"
}


nginx_vhost_already_processed(){
  local vhost_path="${1}"
  file_content_matches "$vhost_path" "# Post-processed by Keitaro ${TOOL_NAME} tool v${RELEASE_VERSION}"
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

fail() {
  local message="${1}"
  local see_logs="${2}"
  log_and_print_err "*** $(translate errors.program_failed) ***"
  log_and_print_err "$message"
  if isset "$see_logs"; then
    log_and_print_err "$(translate errors.see_logs)"
  fi
  print_err
  clean_up
  exit "${3:-${FAILURE_RESULT}}"
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

init_kctl() {
  init_kctl_dirs_and_links
  init_log "${LOG_PATH}"
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
    chmod 0700 "${ETC_DIR}" &&
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
  find "${log_dir}" -name "${log_filename}-*" | sort | head -n -${LOGS_TO_KEEP} | xargs rm -f
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
#





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
  if ! empty "$color"; then
    escape_sequence="\e[${COLOR_CODE[$color]}m"
    echo -e "${escape_sequence}${message}${RESET_FORMATTING}"
  else
    echo "$message"
  fi
}

start_or_reload_nginx(){
  if (file_exists "/run/nginx.pid" && [[ -s "/run/nginx.pid" ]]) || is_ci_mode; then
    debug "Nginx is started, reloading"
    run_command "systemctl reload nginx" "$(translate 'messages.reloading_nginx')" 'hide_output'
  else
    debug "Nginx is not running, starting"
    print_with_color "$(translate 'messages.nginx_is_not_running')" "yellow"
    run_command "systemctl start nginx" "$(translate 'messages.starting_nginx')" 'hide_output'
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
      fail "${fail_message}" "see_logs"
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
  MAX_LINES_COUNT=20
  print_content_of "${file}" |  tail -n "$MAX_LINES_COUNT"
}


remove_current_command(){
  local current_command_script="${1}"
  debug "Removing current command script and logs"
  rm -f "$CURRENT_COMMAND_OUTPUT_LOG" "$CURRENT_COMMAND_ERROR_LOG" "$current_command_script"
  rmdir "$(dirname "$current_command_script")"
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
  print_err "Try '${SCRIPT_NAME} -h' for more information."
  print_err
}

usage_en_header(){
  print_err "Usage: ${SCRIPT_NAME} [OPTION]..."
}

help_en_common(){
  print_err "Miscellaneous:"
  print_err "  -h                       display this help text and exit"
  print_err
  print_err "  -v                       display version information and exit"
  print_err
}

join_by(){
  local delimiter=$1
  shift
  echo -n "$1"
  shift
  printf "%s" "${@/#/${delimiter}}"
}

to_lower(){
  local string="${1}"
  echo "${string,,}"
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


validate_presence(){
  local value="${1}"
  isset "$value"
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


stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
}


parse_options(){
  while getopts ":D:fhvL:l:" option; do
    argument=$OPTARG
    case $option in
      D)
        VARS['ssl_domains']=$argument
        ensure_valid D ssl_domains validate_domains_list
        ;;
      f)
        FORCE_ISSUING_CERTS=true
        ;;
      *)
        common_parse_options "$option" "$argument"
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
  if isset "${VARS['ssl_domains']}"; then
    fail "You should set domains with -d option only"
  fi
  print_deprecation_warning 'Please set domains with -D option'
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
  print_err "  -D DOMAINS               issue certs for domains, DOMAINS=domain1.tld[,domain2.tld...]."
  print_err
  print_err "  -f                       force issuing certs (disable compatility check)."
  print_err
}

stage2(){
  debug "Starting stage 2: make some asserts"
  assert_caller_root
  assert_that_another_certbot_process_not_runing
  detect_installed_version
  run_obsolete_tool_version_if_need
}

stage3(){
  debug "Starting stage 3: get user vars"
  get_user_vars
}

get_user_vars() {
  debug 'Read vars from user input'
  hack_stdin_if_pipe_mode
  if empty "${VARS['ssl_domains']}"; then
    get_user_var 'ssl_domains' 'validate_presence validate_domains_list'
  fi
  VARS['ssl_domains']="$(to_lower "${VARS['ssl_domains']}")"
}

stage4(){
  debug "Starting stage 4: install LE certificates"
  generate_certificates
  if isset "$SUCCESSFUL_DOMAINS"; then
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
  #Clean log before start
  clear_log_before_certificate_request "${CERTBOT_LOG}"
  initialize_additional_ssl_logging_for_domain "${domain}"
  if certificate_exists_for_domain "$domain"; then
    SUCCESSFUL_DOMAINS+=("${domain}")
    debug "Certificate already exists for domain ${domain}"
    print_with_color "${domain}: $(translate 'warnings.certificate_exists_for_domain')" "yellow"
    certificate_generated=${TRUE}
  else
    debug "Certificate for domain ${domain} does not exist"
    if request_certificate_for "${domain}"; then
      SUCCESSFUL_DOMAINS+=("${domain}")
      debug "Certificate for domain ${domain} successfully issued"
      certificate_generated=${TRUE}
    else
      FAILED_DOMAINS+=("${domain}")
      debug "There was an error while issuing certificate for domain ${domain}"
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
  local domain="${1}"
  local additional_log_path
  additional_log_path="$(tmp_ssl_log_path_for_domain "${domain}")"
  echo -n > "${additional_log_path}"
  debug "Start copying logs to ${additional_log_path}"
  ADDITIONAL_LOG_PATH="${additional_log_path}"
}

finalize_additional_ssl_logging_for_domain() {
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
    fail "errors.unexpected" "see_logs"
  fi
}

certificate_exists_for_domain(){
  local domain="${1}"
  directory_exists "/etc/letsencrypt/live/${domain}"
}

request_certificate_for(){
  local domain="${1}"
  local certbot_command=""
  debug "Requesting certificate for domain ${domain}"
  certbot_command="$(build_certbot_command) certonly"
  certbot_command="${certbot_command} --webroot --webroot-path=${WEBAPP_ROOT}"
  certbot_command="${certbot_command} --agree-tos --non-interactive"
  certbot_command="${certbot_command} --domain ${domain}"
  certbot_command="${certbot_command} --register-unsafely-without-email"
  certbot_command="${certbot_command} --preferred-chain '${CERTBOT_PREFERRED_CHAIN}'"
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

generate_vhost_ssl_enabler() {
  local domain="${1}"
  local certs_root_path="/etc/letsencrypt/live/${domain}"
  generate_vhost "$domain" \
      "s|ssl_certificate .*|ssl_certificate ${certs_root_path}/fullchain.pem;|" \
      "s|ssl_certificate_key .*|ssl_certificate_key ${certs_root_path}/privkey.pem;|"
}
#






show_finishing_message(){
  local color=""
  if isset "$SUCCESSFUL_DOMAINS" && empty "$FAILED_DOMAINS"; then
    print_with_color "$(translate 'messages.successful')" 'green'
    print_enabled_domains
  fi
  if isset "$SUCCESSFUL_DOMAINS" && isset "$FAILED_DOMAINS"; then
    print_enabled_domains
    print_not_enabled_domains 'yellow'
  fi
  if empty "$SUCCESSFUL_DOMAINS" && isset "$FAILED_DOMAINS"; then
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


recognize_error() {
  local certbot_log="${1}"
  local key="unknown_error"
  debug "$(print_content_of "${certbot_log}")"
  if grep -q '^There were too many requests' "${certbot_log}"; then
    key="too_many_requests"
  else
    local error_detail
    error_detail=$(grep '^   Detail:' "${certbot_log}" 2>/dev/null)
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


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   http://blog.existentialize.com/dont-pipe-to-your-shell.html
enable_ssl(){
  init "$@"
  stage1 "$@"
  stage2
  stage3
  stage4
}

enable_ssl "$@"
