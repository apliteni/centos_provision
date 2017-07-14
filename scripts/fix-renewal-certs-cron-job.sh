#!/usr/bin/env bash

set -o pipefail
crontab -l -u nginx | sed 's/certbot renew.*/certbot renew --allow-subset-of-names --quiet \&\& nginx -s reload/g' | crontab -u nginx -
