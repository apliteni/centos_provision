#!/usr/bin/env bash
#


check_thp_disable_possibility(){
  if ! "$ENV['CI']"; then
    if pgrep "/sys/kernel/mm/transparent_hugepage/enabled" &>/dev/null; then
      print_with_color "thp not allowed in this system" 'grey'
    else
      echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag
      thp_defrag="$(cat /sys/kernel/mm/transparent_hugepage/defrag)"
      thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
      if [   "$thp_defrag" == "$thp_enabled" ]; then
        if [ "$thp_enabled" == "always madvise [never]" ]; then
          print_with_color "thp disabled" 'green'
        else
          print_err "Impossible to disable thp install will be interrupted" 'red'
          clean_up
          exit 1
        fi
      else
          print_err "Impossible to disable thp install will be interrupted" 'red'
          clean_up
          exit 1
      fi
    fi
  fi
}
