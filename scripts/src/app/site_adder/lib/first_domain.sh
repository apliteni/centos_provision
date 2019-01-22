#!/usr/bin/env bash

first_domain(){
  echo "${VARS['site_domains']%%,*}"
}
