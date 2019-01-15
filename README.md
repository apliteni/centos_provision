# Provision CentOS for Keitaro

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 7

## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    yum update -y && curl keitaro.io/install.sh > run && bash run

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    yum update -y && curl keitaro.io/install.sh > run && bash run -l en

## Install Let's Encrypt Free SSL certificates (optional)

Installer will ask you to install Free SSL certificates. If you don't want to install certificates at a time of
installing Keitaro you may want to install they later.

Connect to your CentOS server and run as root

    curl keitaro.io/enable-ssl.sh > run; bash run domain.ru domain2.ru domain3.ru

SSL certificates installer supports two locales: English (default) and Russian. In order to use Russian locale
run as root

    curl -sSL https://keitaro.io/enable-ssl.sh | bash -s -- -l ru domain1.tld [domain2.tld...]

## Add custom php site (optional)

You can add new php site with `add-site.sh` script. Script asks you new site params (domain, site root) and
generates config file for Nginx.

Connect to your CentOS server and run as root

    curl -sSL https://keitaro.io/add-site.sh | bash

In order to use Russian locale run as root

    curl -sSL https://keitaro.io/add-site.sh | bash -s -- -l ru


## FAQ

### How to specify installation package

    run -a http://keitaro.io/test.zip


### How to specify ansible tags

    run -t tag1,tag2

or ignore

    run -i tag3,tag4


