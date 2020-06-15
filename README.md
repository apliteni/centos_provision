# Keitaro Installer for CentOS 7+

This repository contains a bash installer and an Ansible playbook to provision new bare servers.

## Compatibility
 - CentOS 7
 
## Install Keitaro with bash installer

Connect to your CentOS server and run as root

    yum update -y && curl keitaro.io/install.sh > install && bash install

Installer supports two locales: English (default) and Russian. In order to use Russian locale run as root

    yum update -y && curl keitaro.io/install.sh > install && bash install -L ru

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

    kctl-delete-ssl domain1.com

Where domain.com - name of your domain, which you want to revoke and delete it's certificate. All certificates and their files, their keys, and configuration files of nginx of selected domain will be deleted (located in /etc/nginx/conf.d/). 


## Add custom php site (optional)

You can add new php site with `add-site.sh` script. Script asks you new site params (domain, site root) and
generates config file for Nginx.

Connect to your CentOS server and run as root

    kctl-add-site -D domain.com -R /var/www/domain.com

In order to use Russian locale run as root

    kctl-add-site -D domain.com -R /var/www/domain.com -L ru

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
