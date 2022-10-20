# Keitaro Installer for CentOS 8+

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 8
 - CentOS 8 Stream
 - CentOS 9 Stream

## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    curl keitaro.io/install.sh | bash

## Usage

### kctl
<!-- start of 'kctl help' output -->

```
kctl - Keitaro management tool

Usage:

  kctl [module] [action] [options]

Example:

  kctl install

Actions:
   kctl install                           - install and tune tracker and system components
   kctl upgrade                           - upgrades system & tracker
   kctl rescue                            - fixes common problems
   kctl downgrade [version]               - downgrades tracker to version (by default downgrades to latest stable version)
   kctl install-tracker <version>         - installs tracker with specified version

Modules:
   kctl certificates                      - manage LE certificates
   kctl features                          - manage features
   kctl podman                            - manage podman containers
   kctl resolvers                         - manage DNS resolvers
   kctl transfers                         - manage tracker data transfers
   kctl run                               - simplifies running dockerized commands

Environment variables:

  TRACKER_STABILITY                       - Set up stability channel stable|unstsable. Default: stable

```

<!-- end of 'kctl help' output -->

### kctl certificates
<!-- start of 'kctl certificates help' output -->

```
Usage:
  kctl certificates issue domain1.tld domain2.tld ...     issue LE certificates for specified domains
  kctl certificates revoke domain1.tld domain2.tld ...    revoke LE certificates for specified domains
  kctl certificates prune abandoned                       removes LE certificates without appropriate nginx configs
  kctl certificates prune broken                          removes nginx domains with inconsistent LE certificates
  kctl certificates prune detached                        removes nginx domains are not presented in the Keitaro DB
  kctl certificates prune safe                            removes abandoned & broken certificates
  kctl certificates prune all                             removes abandoned, broken & detached certificates
  kctl certificates renew                                 renew LE certificates
  kctl certificates remove-old-logs                       remove old issuing logs

Supported features: rbooster

```

<!-- end of 'kctl certificates help' output -->

### kctl features
<!-- start of 'kctl features help' output -->

```
Usage:
  kctl features enable <feature>                  enable feature
  kctl features disable <feature>                 disable feature
  kctl features list                              list supported features

Supported features: rbooster

```

<!-- end of 'kctl features help' output -->

### kctl podman
<!-- start of 'kctl podman help' output -->

```
Usage:
  kctl podman prune CONTAINTER_NAME              removes container and storage assotiated with it
  kctl podman statistics [--format json]         prints statistics
  kctl podman usage                              prints this info
```

<!-- end of 'kctl podman help' output -->

### kctl resolvers
<!-- start of 'kctl resolvers help' output -->

```
Usage:
  kctl resolvers set-google                        sets google dns
  kctl resolvers reset                             resets settings
  kctl resolvers usage                             prints this page
```

<!-- end of 'kctl resolvers help' output -->

### kctl transfers
<!-- start of 'kctl-transfers help' output -->

```
Usage: kctl-transfers ACTION [HOST] [BACKUP_PATH]

ACTION
  dump                  - dump Keitaro data from HOST to BACKUP_PATH directory
  restore               - restore Keitaro data from BACKUP_PATH directory on the current host
  copy-from             - dump Keitaro data from HOST to BACKUP_PATH directory and restore it on the current host
  restore-from-sql       - restore Keitaro database from mysql dump file placed by BACKUP_PATH on the specified host

HOST
  local                 - specify local host
  IP_ADDRESS            - use valid IP address to specify remote host

BACKUP_DIR
  Specify Keitaro data directory (default - /var/lib/kctl-transfers)

Environment variables:
  SSH_PASSWORD          - specify ssh password
  SSH_PORT              - specify ssh port
  SSH_PATH_TO_KEY       - specify path to ssh key
Environment variables for restore-from-sql action:
  SALT                  - specify old tracker salt key, mandatory
  POSTBACK_KEY          - specify old tracker postback key

Examples:
  SSH_PASSWORD=mypassword kctl-transfer copy-from 1.2.3.4
  SALT=3a4e4a2c749c421cb8a75ba9f8fbbf2b kctl-transfer restore-from-sql local ./keitaro.sql.gz

```

<!-- end of 'kctl-transfers help' output -->

### kctl run
<!-- start of 'kctl run help' output -->

```
Usage:
  kctl run clickhouse-client                  start clickhouse shell
  kctl run clickhouse-query                   execute clickhouse query
  kctl run mysql-client                       start mysql shell
  kctl run mysql-query                        execute mysql query
  kctl run cli-php                            execute cli.php command
  kctl run redis-client                       execute redis shell
  kctl run nginx                              perform nginx command
  kctl run certbot                            perform certbot command
```

<!-- end of 'kctl run help' output -->

### kctl-install
<!-- start of 'kctl-install -h' output -->

```
Usage: kctl-install [OPTION]...

kctl-install installs and configures Keitaro

Example: kctl-install

Automation:
  -U                       upgrade the system configuration and tracker

  -C                       rescue the system configuration and tracker

  -R                       restore tracker using dump

  -F DUMP_FILEPATH         set filepath to dump (-S and -R should be specified)

  -S SALT                  set salt for dump restoring (-F and -R should be specified)

Customization:
  -a PATH_TO_PACKAGE       set path to Keitaro installation package

  -t TAGS                  set ansible-playbook tags, TAGS=tag1[,tag2...]

  -i TAGS                  set ansible-playbook ignore tags, TAGS=tag1[,tag2...]

  -o output                sset the full path of the installer log output

  -w                       do not run 'yum upgrade'

Miscellaneous:
  -h                       display this help text and exit

  -v                       display version information and exit

Environment variables:

  TRACKER_STABILITY       Set up stability channel stable|unstsable. Default: stable

```

<!-- end of 'kctl-install -h' output -->

## FAQ

### How to specify installation package

    kctl-install -a http://keitaro.io/test.zip

### How to specify ansible tags

    kctl-install -t tag1,tag2

or ignore

    kctl-install -i tag3,tag4

### How to upgrade kctl tool set

    kctl upgrade

### How to reinstall tracker

    kctl install-tracker [VERSION]
    Example: kctl install-tracker 9.14.22

### How to repair tracker

    kctl rescue


## Update README

This README is assembled from README.tpl by calling appropriate `kctl ... help` commands. If you need to update static part, update README.tpl. If you need to update Usage run `make readme` and commit changes.
