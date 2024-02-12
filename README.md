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
  kctl check                      - checks if all componets operates normally
  kctl downgrade                  - installs the latest stable tracker version
  kctl install                    - installs tracker and system components
  kctl repair                     - fixes common problems
  kctl tune                       - tunes all components
  kctl update                     - updates system & tracker (you have to to set UPDATE_CHANNEL or KEITARO_VERSION)
  kctl use-clickhouse-olapdb      - configures Keitaro to use ClickHouse as OLAP DB

Modules:
  kctl certificates               - manage LE certificates
  kctl podman                     - manage podman containers
  kctl resolvers                  - manage DNS resolvers
  kctl run                        - simplifies running dockerized commands
  kctl support-team-access        - allow/deny access to this server to Keitaro support team
  kctl tracker-options            - manage tracker options
  kctl transfers                  - manage tracker data transfers
```

<!-- end of 'kctl help' output -->

### kctl certificates
<!-- start of 'kctl certificates help' output -->

```
Usage:
  kctl certificates issue DOMAIN1[ DOMAIN2][...]          issue LE certificates for the specified domains
  kctl certificates revoke DOMAIN1[ DOMAIN2][...]         revoke LE certificates for the specified domains
  kctl certificates renew                                 renew LE certificates
  kctl certificates remove-old-logs                       remove old issuing logs
  kctl certificates prune <KIND>                          prunes LE ssl certificates

    KINDs:
      abandoned                                           removes LE certificates without appropriate nginx configs
      broken                                              removes nginx domains with inconsistent LE certificates
      detached                                            removes nginx domains are not presented in the Keitaro DB
      irrelevant                                          removes nginx domains with expired certificates not presented in the Keitaro DB
      safe                                                removes abandoned, broken & irrelevant certificates
      all                                                 removes abandoned, broken, irrelevant & detached certificates
```

<!-- end of 'kctl certificates help' output -->

### kctl tracker-options
<!-- start of 'kctl tracker-options help' output -->

```
Usage:
  kctl tracker-options enable <tracker_option>                  enable tracker_option
  kctl tracker-options disable <tracker_option>                 disable tracker_option
  kctl tracker-options help                                     print this help
```

<!-- end of 'kctl tracker-options help' output -->

### kctl podman
<!-- start of 'kctl podman help' output -->

```
Usage:
  kctl podman start COMPONENT                   starts COMPONENT's container (it stops and prunes COMPONENT before)
  kctl podman stop  COMPONENT                   stops COMPONENT's container
  kctl podman prune COMPONENT                   removes COMPONENT's container and storage assotiated with it
  kctl podman stats                             prints statistics
  kctl podman usage                             prints this info

Allowed COMPONENTs are: nginx-starting-page kctl system-redis redis kctld mariadb clickhouse kctl-ch-converter tracker roadrunner nginx certbot certbot-renew
```

<!-- end of 'kctl podman help' output -->

### kctl resolvers
<!-- start of 'kctl resolvers help' output -->

```
Usage:
  kctl resolvers autofix                           sets google dns if current resolver works slow
  kctl resolvers set-google                        sets google dns
  kctl resolvers reset                             resets settings
  kctl resolvers usage                             prints this page
```

<!-- end of 'kctl resolvers help' output -->

### kctl transfers
<!-- start of 'kctl-transfers help' output -->

```
Usage: kctl transfers ACTION [HOST] [BACKUP_PATH]

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
  SSH_USER              - specify ssh user
  SSH_PASSWORD          - specify ssh password
  SSH_PORT              - specify ssh port
  SSH_PATH_TO_KEY       - specify path to ssh key
Environment variables for restore-from-sql action:
  SALT                  - specify old tracker salt key, mandatory
  POSTBACK_KEY          - specify old tracker postback key

Examples:
  SSH_PASSWORD=mypassword kctl transfers copy-from 1.2.3.4
  SALT=3a4e4a2c749c421cb8a75ba9f8fbbf2b kctl transfers restore-from-sql local ./keitaro.sql.gz
```

<!-- end of 'kctl-transfers help' output -->

### kctl run
<!-- start of 'kctl run help' output -->

```
Usage:
  kctl run clickhouse-client                  run clickhouse keitaro db shell
  kctl run clickhouse-query                   execute clickhouse keitaro db query
  kctl run mariadb-client                     run mariadb keitaro db shell
  kctl run mariadb-query                      execute mariadb keitaro db query
  kctl run redis-client                       run redis keitaro db shell
  kctl run redis-query                        execute redis keitaro db query
  kctl run system-clickhouse-client           run clickhouse system db shell
  kctl run system-clickhouse-query            execute clickhouse system db query
  kctl run system-mariadb-client              run mariadb system db shell
  kctl run system-mariadb-query               execute mariadb system db query
  kctl run system-redis-client                run redis system db shell
  kctl run system-redis-query                 execute redis system db query
  kctl run cli-php <command>                  execute cli.php command
  kctl run nginx <command>                    perform nginx command
  kctl run certbot                            perform certbot command
  kctl run certbot-renew                      perform certbot-renew command
```

<!-- end of 'kctl run help' output -->

### kctl-install
<!-- start of 'kctl-install -h' output -->

```
Usage: kctl-install [OPTION]...

kctl-install installs and configures Keitaro

Example: ANSIBLE_IGNORE_TAGS=tune-swap LOG_PATH=/dev/stderr kctl-install

Modes:
  -U                       updates the system configuration and tracker

  -R                       repairs the system configuration and tracker

  -T                       tunes the system configuration and tracker

Environment variables:
  LOG_PAH                  sets the log output file

  ANSIBLE_TAGS             sets ansible-playbook tags, ANSIBLE_TAGS=tag1[,tag2...]

  ANSIBLE_IGNORE_TAGS      sets ansible-playbook ignore tags, ANSIBLE_IGNORE_TAGS=tag1[,tag2...]
Miscellaneous:
  -h                       display this help text and exit

  -v                       display version information and exit

Environment variables:

  TRACKER_STABILITY       Set up stability channel stable|unstsable. Default: stable
```

<!-- end of 'kctl-install -h' output -->

## FAQ

### How to force tracker to use ClickHouse as OLAP DB

    kctl use-clickhouse

### How to update kctl tool set

    kctl update

### How to reinstall tracker

    kctl install-tracker [VERSION]
    Example: kctl install-tracker 9.14.22

### How to repair tracker

    kctl repair


## Update README

This README is assembled from README.tpl by calling appropriate `kctl ... help` commands. If you need to update static part, update README.tpl. If you need to update Usage run `make readme` and commit changes.
