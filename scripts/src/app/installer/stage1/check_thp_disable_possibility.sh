#!/usr/bin/env bash
#


check_thp_disable_possibility(){
  if pgrep "/sys/kernel/mm/transparent_hugepage/enabled" &>/dev/null; then
    echo 'thp отсутствует в системе'
  else
    echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag
    error_message="\e[91mНевозможно отключить thp. Установка будет прервана\033[0m"
    thp_defrag="$(cat /sys/kernel/mm/transparent_hugepage/defrag)"
    thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
    if [ "$thp_defrag" == "$thp_enabled" ]; then
      if [ "$thp_enabled" == "always madvise [never]" ]; then
        echo -e "\e[32mthp disabled, thats OK\033[0m"
      else
        echo -e "${error_message}"
        exit 1
      fi
    else
      echo -e "${error_message}"
      exit 1
    fi
  fi
}
