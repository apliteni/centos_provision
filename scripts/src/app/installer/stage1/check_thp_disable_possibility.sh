#!/usr/bin/env bash
#

check_openvz(){
  virtualization_type="$(hostnamectl status | grep 'Virtualization')"
  if isset "$virtualization_type" && "$virtualization_type" == "Virtualization: openvnz"; then
    print_err "Cannot install on server with OpenVZ virtualization" 'red'
    clean_up
    exit 1
  fi
}

check_thp_disable_possibility(){
  if empty "${CI}"; then
    if is_file_exist "/sys/kernel/mm/transparent_hugepage/enabled" && is_file_exist "/sys/kernel/mm/transparent_hugepage/defrag"; then
      echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag
      thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
      if "$thp_enabled" == "always madvise [never]" ; then
        print_with_color "Before installation check possibility to disalbe THP" 'blue'
        print_with_color ". OK" 'green'
      else
        print_err "Impossible to disable thp install will be interrupted" 'red'
        clean_up
        exit 1
      fi
    fi
  fi
}
