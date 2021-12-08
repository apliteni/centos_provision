# Keitaro Installer for CentOS 7+

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 7
 - CentOS 8

## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    curl keitaro.io/install.sh | bash

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    curl keitaro.io/install.sh | bash -s -- -L ru

## Install Let's Encrypt Free SSL certificates (optional)

Installer will ask you to install Free SSL certificates. If you don't want to install certificates at a time of
installing Keitaro you may want to install they later.

Connect to your CentOS server and run as root

    kctl-enable-ssl -D domain1.com,domain2.com

SSL certificates installer supports two locales: English (default) and Russian. In order to use Russian locale
run as root

    kctl-enable-ssl -D domain1.com,domain2.com -L ru


# Delete SSL certificates

In case, when you need to remove SSL certificate from domain of your site, you can use our special script which will delete SSL certificate and domain. Script will take domain name as parameter. To delete ssl certificate, you can use following command:

    kctl-disable-ssl -D domain1.com,domain2.com

Where domain1.com - name of your domain, which you want to revoke and delete it's certificate. All certificates and their files, their keys, and configuration files of nginx of selected domain will be deleted (located in /etc/nginx/conf.d/).


## Add custom php site (optional)

You can add new php site with `add-site.sh` script. Script asks you new site params (domain, site root) and
generates config file for Nginx.

Connect to your CentOS server and run as root

    kctl-add-site -D domain.com -R /var/www/domain.com

In order to use Russian locale run as root

    kctl-add-site -D domain.com -R /var/www/domain.com -L ru

## Run from mysql to clickhouse migrator

Run from the server terminal:

    kctl-ch-migrator --prefix keitaro_ --ms-host localhost --ms-db keitaro --ms-user keitaro --ms-password mysql_password --ch-host localhost --ch-user keitaro --ch-password clickhouse_password --ch-db keitaro

For get mysql and clickhouse password run:

    cat /etc/keitaro/config/inventory

## Developing

Source files placed in the scripts/ dir. After making changes you should assemble affected tools.
From the scripts/ directory use one of the following commands:

    # Build and test
    make                        # to build and test all tools
    make installer              # to build and test install.sh
    make ssl_enabler            # to build and test enable-ssl.sh
    make site_adder             # to build and test add-site.sh
    # Build only
    make compile                # to build all tools
    make compile_installer      # to build install.sh
    make compile_ssl_enabler    # to build enable-ssl.sh
    make compile_site_adder     # to build add-site.sh
    # Test only
    make test                   # to test all tools
    make test_installer         # to test install.sh
    make test_ssl_enabler       # to test enable-ssl.sh
    make test_site_adder        # to test add-site.sh

## Release (through CI/CD)

Change version in file `RELEASE_VERSION`, commit changes.

Create a MR or push it to master:

    git push origin master

## Release (manual)

After making changes ans pushing them into the master branch you should update release tags (from the root repo dir)

    make release

This command reads current release from RELEASE_VERSION file (eg. X.Y) and associate vX.Y tag and release-X.Y branch with current commit

## FAQ

### How to specify installation package

    kctl-install -a http://keitaro.io/test.zip


### How to specify ansible tags

    kctl-install -t tag1,tag2

or ignore

    kctl-install -i tag3,tag4

### How to install without license key

    curl keitaro.io/install.sh | bash -s -- -W

### How to upgrade tracker

    kctl upgrade

### How to downgrade tracker

    kctl downgrade <version>
    Example: kctl downgrade 9.13

### How to repair  tracker or start fill upgrade

    kctl doctor

## Variables and flags

KCTL_TRACKER_STABILITY - SetUp stability channel stable|unstsable|e.g. default: stable 
