#!/usr/bin/env bash
#


check_thp_disable_possibility(){
  echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag
  ERROR='\033[0;31m'
  NC='\033[0m' # put to end of string for remove color scheme after error
  thp_defrag="$(cat /sys/kernel/mm/transparent_hugepage/defrag)"
  thp_enabled="$(cat /sys/kernel/mm/transparent_hugepage/enabled)"
  if [ "$thp_defrag" == "$thp_enabled" ]; then
    if [ "$thp_enabled" == "always madvise [never]" ]; then
      echo "thp disabled, thats OK"
    else
      echo -e "${ERROR}Невозможно отключить thp. Установка будет прервана${NC}"
      exit 1
    fi
  else
    echo -e "${ERROR}Невозможно отключить thp. Установка будет прервана${NC}"
    exit 1
  fi
}
