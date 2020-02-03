#!/bin/bash

# Check if certbot-auto executed
FILECERT=/usr/local/bin/certbot-auto
filecertbot=certbot
if test -f "$FILECERT"; then
  filecertbot=$FILECERT
  else
    filecertbot=certbot
fi

DOMAIN="$1"
echo "Following SSL certificates and virtual hosts would be deleted & removed:" $1
export DOMAIN;
rm -rf /etc/letsencrypt/{live,renewal,archive}/{${DOMAIN},${DOMAIN}.conf;
rm -rf /etc/nginx/conf.d/${DOMAIN}.conf;
$filecertbot delete --cert-name $DOMAIN;
