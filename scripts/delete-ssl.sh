#!/bin/bash
DOMAIN="$1"
echo "Following SSL certificates and virtual hosts would be deleted & removed:" $1
export DOMAIN;
rm -rf /etc/letsencrypt/{live,renewal,archive}/{${DOMAIN},${DOMAIN}.conf;
rm -rf /etc/nginx/conf.d/${DOMAIN}.conf;
certbot-auto delete --cert-name $DOMAIN;
