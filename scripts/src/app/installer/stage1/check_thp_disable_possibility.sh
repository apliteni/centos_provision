#!/usr/bin/env bash
#

check_openvz(){
  if ! is_ci_mode; then
    virtualization_type="$(hostnamectl status | grep Virtualization | sed -n "s/\s*Virtualization:\s*//p")"
    if isset "$virtualization_type" && [ "$virtualization_type" == "openvnz" ]; then
      print_err "Cannot install on server with OpenVZ virtualization" 'red'
      clean_up
      exit 1
    fi
  fi
}

check_thp_disable_possibility(){
  if ! is_ci_mode; then
    if is_file_exist "/sys/kernel/mm/transparent_hugepage/enabled" && is_file_exist "/sys/kernel/mm/transparent_hugepage/defrag"; then
      echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag
      thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
      if [ "$thp_enabled" == "always madvise [never]" ]; then
        echo -e "\e[${COLOR_CODE['blue']}mBefore installation check possibility to disalbe THP \e[${COLOR_CODE['green']}m. OK ${RESET_FORMATTING}"
      else
        print_err "Impossible to disable thp install will be interrupted" 'red'
        clean_up
        exit 1
      fi
    fi
  fi
}
