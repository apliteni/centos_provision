#!/usr/bin/env bash

# If installed version less than or equal to version from checkpoint 
# then ANSIBLE_TAGS will be expanded by upgrade-from-x.y tag
# Example: 
#   when UPGRADE_CHECKPOINTS=(1.5 2.0 2.12 2.13)
#     and insalled version is 2.12
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `upgrade-from-2.12` and `upgrade-from-2.13` tags 
UPGRADE_CHECKPOINTS=(1.5 2.0 2.12 2.13)

# If installed version less than or equal to version from array value
# then ANSIBLE_TAGS will be expanded by appropriate tags (given from array key)
# Example: 
#   when REPLAY_ROLE_TAGS_ON_UPGRADE_FROM=( ['init']='1.0' ['enable-swap']='2.0' )
#     and insalled version is 2.0
#     and we are upgrading to 2.14
#   then ansible tags will be expanded by `enable-swap` tag
declare -A REPLAY_ROLE_TAGS_SINCE=(
  ['configure-journald']='2.12'
  ['configure-timezone']='0.9'
  ['create-tracker-user-and-dirs']='1.0'
  ['disable-ipv6']='1.0'
  ['disable-thp']='0.9'
  ['enable-firewall']='1.9'
  ['enable-repo-remi']='2.5'
  ['enable-swap']='2.0'
  ['increase-max-opened-files']='1.0'
  ['install-certbot']='2.13'
  ['install-certs']='2.13'
  ['install-kctl-tools']='2.12'
  ['install-ntp']='1.14'
  ['install-packages']='1.4'
  ['install-postfix']='2.13'
  ['install-mariadb']='2.13' # 0.9
  ['install-tokudb']='2.13'  # 0.9
  ['tune-mariadb']='2.13'    # 1.17
  ['tune-redis']='1.4'
  ['install-nginx']='1.0'
  ['tune-nginx']='2.13'
  ['install-php']='2.12'
  ['install-php-fpm']='2.12'
  ['tune-php-fpm']='2.12'
  ['install-roadrunner']='2.12'
  ['tune-roadrunner']='1.16'
  ['tune-tracker']='1.14'
)
expand_ansible_tags_on_upgrade() {
  if is_upgrade_mode_set; then
    debug "Upgrade mode is detected, expading ansible tags"
    expand_ansible_tags_by_upgrade_from_tags
    expand_ansible_tags_by_role_tags
    debug "ANSITBLE_TAGS is set to ${ANSIBLE_TAGS}"
  fi
}


expand_ansible_tags_by_upgrade_from_tags() {
  for version in "${UPGRADE_CHECKPOINTS[@]}"; do
    if (( $(as_version ${INSTALLED_VERSION}) <= $(as_version ${version}) )); then
      ANSIBLE_TAGS="${ANSIBLE_TAGS},upgrade-from-${version}"
    fi
  done
}

expand_ansible_tags_by_role_tags() {
  for role_tag in ${!REPLAY_ROLE_TAGS_SINCE[@]}; do
    replay_role_tag_since=${REPLAY_ROLE_TAGS_SINCE[${role_tag}]}
    echo role: ${role_tag} version: ${replay_role_tag_since}
    if (( $(as_version ${INSTALLED_VERSION}) <= $(as_version ${replay_role_tag_since}) )); then
      ANSIBLE_TAGS="${ANSIBLE_TAGS},${role_tag}"
    fi
  done
}
