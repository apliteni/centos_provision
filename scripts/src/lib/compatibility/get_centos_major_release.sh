#!/usr/bin/env bash

get_centos_major_release() {
  grep -oP '(?<=release )\d+' /etc/centos-release
}

