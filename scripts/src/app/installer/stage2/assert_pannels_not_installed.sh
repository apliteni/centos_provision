#!/usr/bin/env bash
#





assert_pannels_not_installed(){
  if isset "$SKIP_CHECKS"; then
    debug "SKIPPED: actual checking of panels skipped"
  else
    if is_installed mysql; then
      assert_isp_manager_not_installed
      assert_vesta_cp_not_installed
    fi
  fi
}


assert_isp_manager_not_installed(){
  if isp_manager_installed; then
    debug "ISP Manager databases detected"
    fail "$(translate errors.isp_manager_installed)"
  fi
}


assert_vesta_cp_not_installed(){
  if vesta_cp_installed; then
    debug "Vesta CP databases detected"
    fail "$(translate errors.vesta_cp_installed)"
  fi
}


isp_manager_installed(){
  databases_exist roundcube test
}


vesta_cp_installed(){
  databases_exist admin_default roundcube
}


databases_exist(){
  local db1="${1}"
  local db2="${2}"
  debug "Detect exist databases ${db1} ${db2}"
  mysql -Nse 'show databases' | tr '\n' ' ' | grep -Pq "${db1}.*${db2}"
}
