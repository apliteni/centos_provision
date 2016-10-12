FROM centos

ENV MAJOR_CENTOS_VERSION=7 \
    PHP_VERSION=php56

RUN yum install -y deltarpm epel-release \
    && rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-${MAJOR_CENTOS_VERSION}.rpm \
    && yum update -y

RUN yum install -y --enablerepo=remi ${PHP_VERSION} \
                                     ${PHP_VERSION}-php-fpm \
                                     ${PHP_VERSION}-php-devel \
                                     ${PHP_VERSION}-php-mysqlnd \
                                     ${PHP_VERSION}-php-pecl-redis \
                                     ${PHP_VERSION}-php-mbstring \
                                     ${PHP_VERSION}-php-pear \
                                     ${PHP_VERSION}-php-xml \
                                     ${PHP_VERSION}-php-memcached \
                                     ${PHP_VERSION}-php-ioncube-loader

RUN ln -s /usr/bin/${PHP_VERSION} /usr/bin/php \
    && ln -s /opt/remi/${PHP_VERSION}/root/bin/php-config /usr/bin/php-config \
    && ln -s /opt/remi/${PHP_VERSION}/root/etc/ /etc/php \
    && ln -s /opt/remi/${PHP_VERSION}/root/var/log/php-fpm/ /var/log/php-fpm

RUN sed -i -e 's/^memory_limit = .*/memory_limit=500M/' /etc/php/php.ini \
    && sed -i -e 's/^daemonize = .*/daemonize = no/' \
              /etc/php/php-fpm.conf \
    && sed -i -e 's/^listen = .*/listen = 0.0.0.0:9000/' \
              -e 's/^listen.allowed_clients =/;listen.allowed_clients =/' \
              -e 's/^;catch_workers_output = .*/catch_workers_output = yes/' \
              -e 's|^;access\.log = .*|access\.log = /proc/self/fd/2|' \
              -e 's|^php_admin_value\[error_log\] = .*|php_admin_value[error_log] = /proc/self/fd/2|' \
              /etc/php/php-fpm.d/www.conf

ENTRYPOINT ["/opt/remi/php56/root/usr/sbin/php-fpm", "-F"]
