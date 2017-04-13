# Provision CentOS for Keitaro TDS

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

# Compatibility
 - CentOS 7, Ansible 2

# How to install

## Installation method 1 (preferred). Use provided bash installer

### Install Keitaro TDS

Connect to your CentOS server and run as root

    curl -sSL https://keitarotds.com/install.sh | bash

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    curl -sSL https://keitarotds.com/install.sh | bash -s -- -l ru

### Install Let's Encrypt Free SSL certificates (optional)

Installer will ask you to install Free SSL certificates. If you don't want to install certificates at a time of
installing Keitaro TDS you may want to install they later.

Connect to your CentOS server and run as root

    curl -sSL https://keitarotds.com/enable-ssl.sh | bash -s -- domain1.tld [domain2.tld...]

SSL certificates installer supports two locales: English (default) and Russian. In order to use Russian locale
run as root

    curl -sSL https://keitarotds.com/enable-ssl.sh | bash -s -- -l ru domain1.tld [domain2.tld...]

### Add custom php site (optional)

You can add new php site with `add-site.sh` script. Script asks you new site params (domain, site root) and
generates config file for Nginx.

Connect to your CentOS server and run as root

    curl -sSL https://keitarotds.com/add-site.sh | bash

In order to use Russian locale run as root

    curl -sSL https://keitarotds.com/add-site.sh | bash -s -- -l ru

## Installation method 2. Run ansible-playbook

### Install Ansible

For OSX

    brew install ansible

For Ubuntu

    apt-get install ansible

### Download and unpack the ansible playbook

    wget https://github.com/keitarocorp/centos_provision/archive/master.zip
    unzip master.zip
    cd master
    cp hosts.example.txt hosts.txt

### Edit file ```hosts.txt```

    [server]
    SERVER_IP                       # 127.0.0.1 if you run local
    
    [server:vars]
    connection=ssh                  # Or change to 'local'

    ansible_user=SSH_LOGIN
    ansible_ssh_pass=SSH_PASSWORD
    db_name=DB_NAME
    db_user=DB_USER
    db_password=DB_PASSWORD
    license_ip=LICENSE_IP
    license_key=LICENSE_KEY
    admin_login=ADMIN_LOGIN
    admin_password=ADMIN_PASSWORD
    # If you want to install Let's Encrypt Free SSL certificates add the following lines
    ssl_certificate=letsencrypt     # You must agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)
    ssl_domains=DOMAIN1,DOMAIN2     # Specify server domains, separated by comma without spaces
    ssl_email=some.mail@example.com # If you want to receive warnings about your certificates from Let's Encrypt
 
### Run playbook

    ansible-playbook -i hosts.txt playbook.yml

Answer ```yes```

    $ ansible-playbook -i hosts.txt playbook.yml
    
    PLAY ***************************************************************************
    
    TASK [setup] *******************************************************************
    The authenticity of host '1.1.1.1)' can't be established.
    ECDSA key fingerprint is SHA256:g0rXmM8dG5+gefA1fW7HgkQ2S9LZjY5y2hzDguZ71y3.
    Are you sure you want to continue connecting (yes/no)?
    yes
    
### Configuration

Take a look to ```vars/server.yml```.

### Install Let's Encrypt Free SSL certificates (optional)

If you don't want to install certificates at a time of installing Keitaro TDS you may want to install they later.
In order to install certificates add the following lines to your ```hosts.txt```

    ssl_certificate=letsencrypt     # You must agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)
    ssl_domains=DOMAIN1,DOMAIN2     # Specify server domains, separated by comma without spaces
    ssl_email=some.mail@example.com # If you want to receive warnings about your certificates from Let's Encrypt


Then run playbook with ssl tag

    ansible-playbook -i hosts.txt playbook.yml --tags ssl

### Troubleshooting

Run ansible

    ansible-playbook -i hosts.txt playbook.yml -vvv

support@keitarotds.com
