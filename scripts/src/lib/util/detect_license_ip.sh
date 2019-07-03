#!/usr/bin/env bash

detect_license_ip(){
  get_host_ips | head -n1
}
