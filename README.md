# Keitaro Installer for CentOS 7+

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 7
 - CentOS 8
 - CentOS 8 Stream

## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    curl keitaro.io/install.sh | bash

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    curl keitaro.io/install.sh | bash -s -- -L ru

## Add custom php site (optional)

You can add new php site with `add-site.sh` script. Script asks you new site params (domain, site root) and
generates config file for Nginx.

Connect to your CentOS server and run as root

    kctl-add-site -D domain.com -R /var/www/domain.com

## Migrate data from mysql to clickhouse

Run from the server terminal:

    kctl-ch-migrator --prefix keitaro_ --ms-host localhost --ms-db keitaro --ms-user keitaro --ms-password mysql_password --ch-host localhost --ch-user keitaro --ch-password clickhouse_password --ch-db keitaro

## FAQ

### How to specify installation package

    kctl-install -a http://keitaro.io/test.zip

### How to specify ansible tags

    kctl-install -t tag1,tag2

or ignore

    kctl-install -i tag3,tag4

### How to upgrade kctl tool set

    kctl upgrade

### How to downgrade tracker

    kctl downgrade [VERSION]
    Example: kctl downgrade

### How to repair tracker or start full upgrade

    kctl doctor

## Variables and flags

KCTL_TRACKER_STABILITY - Set up stability channel stable|unstsable. Default: stable
