Удаление SSL сертификата указанного домена

В том случае если Вам потребуется убрать SSL сертификат с домена Вашего сайта, можете воспользоваться нашим скриптом удаления сертификата. Скрипт принимает доменное имя в качестве параметра. Сертификат SSL Вы можете удалить следующей командой:

curl keitaro.io/delete_ssl.sh > run; bash run domain.com

Где domain.com - это имя Вашего домена, у которого хотите отозвать и удалить сертификат. Будет произведено удаление сертификатов и их файлов, ключей шифрования сертификата указанного домена, а также файлов конфигурации данных сайтов в nginx (расположенных по пути /etc/nginx/conf.d/).


Deleting domain SSL certificate

In case, when you need to remove SSL certificate from domain of your site, you can use our special script which will delete SSL certificate and domain. Script will take domain name as parameter. To delete ssl certificate, you can use following command: 

curl keitaro.io/delete_ssl.sh > run; bash run domain.com

Where domain.com - name of your domain, which you want to revoke and delete it's certificate. All certificates and their files, their keys, and configuration files of nginx of selected domain will be deleted (located in /etc/nginx/conf.d/). 
