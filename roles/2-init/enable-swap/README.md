Ansible Swap Role
=========

[![Build Status](https://travis-ci.org/mikegleasonjr/ansible-role-swap.svg?branch=master)](https://travis-ci.org/mikegleasonjr/ansible-role-swap)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-mikegleasonjr.swap-5bbdbf.svg?style=flat)](https://galaxy.ansible.com/detail#/role/5969)

This role adds a swap file to your host. It currently supports Debian and RedHat distributions.

Requirements
------------

None

Installation
------------

`$ ansible-galaxy install mikegleasonjr.swap`

Role Variables
--------------

Here are the defaults from `defaults/main.yml`:

```
swap_size: "{{ ansible_memtotal_mb }}M"
swap_location: /swap
swap_sysctl_tweaks:
  vm.vfs_cache_pressure: "50"
  vm.swappiness: "10"
```

The default swap size is equivalent to the amount of RAM on the host. It accepts any valid parameter accepted by `fallocate`.

Example Playbook
----------------

```
- hosts: all
  roles:
    - mikegleasonjr.swap
```

Dependencies
------------

none

License
-------

BSD

Contributing
-------

A vagrant environment has been provided to test the role on different distributions. Add your tests in `tests.yml` and...

```
$ vagrant up
$ vagrant provision
```

Author Information
------------------

Mike Gleason jr Couturier (mikegleasonjr@gmail.com)

Other roles from the same author:

- [firewall](https://github.com/mikegleasonjr/ansible-role-firewall)
