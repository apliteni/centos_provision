# Provision CentOS for Keitaro

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 7, Ansible 2

## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    curl -sSL https://keitaro.io/install.sh | bash

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    curl -sSL https://keitaro.io/install.sh | bash -s -- -l ru

## Install Let's Encrypt Free SSL certificates (optional)

Installer will ask you to install Free SSL certificates. If you don't want to install certificates at a time of
installing Keitaro you may want to install they later.

Connect to your CentOS server and run as root

    curl -sSL https://keitaro.io/enable-ssl.sh | bash -s -- domain1.tld [domain2.tld...]

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


support@keitarotds.com
