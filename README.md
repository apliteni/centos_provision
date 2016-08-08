# Provision CentOS for Keitaro TDS

This repository contains ansible playbooks to provision new server.

# Server Requirements
 - CentOS 7

# Client Requirements
 - Ansible

## Install Ansible

For OSX

    brew install ansible

For Ubuntu

    apt-get install ansible

## How to Use

Download and unpack the ansible playbook

    wget https://github.com/keitarocorp/centos_provision/archive/master.zip
    unzip master.zip
    
Create file ```hosts.txt```
     
    [app]
    YOUR_IP
    
    [app:vars]
    ansible_ssh_user=SSH_LOGIN
    ansible_ssh_pass=SSH_PASSWORD
    db_name = DB_NAME
    db_user = DB_USER
    db_password = DB_PASSWORD
    license_ip = LICENSE_IP
    license_key = LICENSE_KEY
    admin_login = ADMIN_LOGIN
    admin_password = ADMIN_PASSWORD
    
Run 

    ansible-playbook -i hosts.txt app.yml


Answer ```yes```

    $ ansible-playbook -i hosts.txt app.yml                                                                                
    
    PLAY ***************************************************************************
    
    TASK [setup] *******************************************************************
    paramiko: The authenticity of host '1.1.1.1' can't be established.
    The ssh-rsa key fingerprint is 73cc4460fc715e389ecd44c0797e6f03.
    Are you sure you want to continue connecting (yes/no)?
    yes
    
    
## Troubleshooting
    
Run ansible with verbose mode

    ansible-playbook -i hosts.txt app.yml -vvvv            
    
support@keitarotds.com 