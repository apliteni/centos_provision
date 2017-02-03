# Provision CentOS for Keitaro TDS

This repository contains an Ansible playbook to provision new bare servers.

# Compatibility
 - CentOS 7, Ansible 2

## Install Ansible

For OSX

    brew install ansible

For Ubuntu

    apt-get install ansible

## How to Use

Download and unpack the ansible playbook

    wget https://github.com/keitarocorp/centos_provision/archive/master.zip
    unzip master.zip
    cd master
    cp hosts.example.txt hosts.txt

Edit file ```hosts.txt```

    [app]
    YOUR_IP
    
    [app:vars]
    ansible_ssh_user=SSH_LOGIN
    ansible_ssh_pass=SSH_PASSWORD
    db_name=DB_NAME
    db_user=DB_USER
    db_password=DB_PASSWORD
    license_ip=LICENSE_IP
    license_key=LICENSE_KEY
    admin_login=ADMIN_LOGIN
    admin_password=ADMIN_PASSWORD
    ssl_certificate=letsencrypt     # If you want to use Free SSL certs from Let's Encrypt
    ssl_domains=DOMAIN1,DOMAIN2     # Specify server domains, separated by comma without spaces

Run 

    ansible-playbook -i hosts.txt playbook.yml


Answer ```yes```

    $ ansible-playbook -i hosts.txt playbook.yml
    
    PLAY ***************************************************************************
    
    TASK [setup] *******************************************************************
    paramiko: The authenticity of host '1.1.1.1' can't be established.
    The ssh-rsa key fingerprint is 73cc4460fc715e389ecd44c0797e6f03.
    Are you sure you want to continue connecting (yes/no)?
    yes
    
## Configuration

Take a look to ```vars/server.yml```.

## Troubleshooting

Run ansible

    ansible-playbook -i hosts.txt playbook.yml -vvv



support@keitarotds.com
