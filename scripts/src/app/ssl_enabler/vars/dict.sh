#!/usr/bin/env bash
#




RECONFIGURE_KEITARO_SSL_COMMAND_EN="curl -sSL ${KEITARO_URL}/install.sh | bash -s -- -l en -t nginx,ssl"

RECONFIGURE_KEITARO_SSL_COMMAND_RU="curl -sSL ${KEITARO_URL}/install.sh | bash -s -- -l ru -t nginx,ssl"

DICT['en.errors.reinstall_keitaro']="Your Keitaro installation does not properly configured. Please reconfigure Keitaro by evaluating command \`${RECONFIGURE_KEITARO_COMMAND_EN}\`"
DICT['en.errors.reinstall_keitaro_ssl']="Nginx settings of your Keitaro installation does not properly configured. Please reconfigure Nginx by evaluating command \`${RECONFIGURE_KEITARO_SSL_COMMAND_EN}\`"
DICT['en.errors.see_logs']="Evaluating log saved to ${SCRIPT_LOG}. Please rerun \`${SCRIPT_COMMAND}\` after resolving problems."
DICT['en.errors.domain_invalid']=":domain: doesn't look as valid domain"
DICT['en.certbot_errors.wrong_a_entry']="Please make sure that your domain name was entered correctly and the DNS A record for that domain contains the right IP address. You need to wait a little if the DNS A record was updated recently."
DICT['en.certbot_errors.too_many_requests']="There were too many requests. See https://letsencrypt.org/docs/rate-limits/."
DICT['en.certbot_errors.unknown_error']="There was unknown error while issuing certificate, please contact support team"
DICT['en.messages.check_renewal_job_scheduled']="Check that the renewal job is scheduled"
DICT['en.messages.check_inactual_renewal_job_scheduled']="Check that inactual renewal job is scheduled"
DICT['en.messages.make_ssl_cert_links']="Make SSL certificate links"
DICT['en.messages.requesting_certificate_for']="Requesting certificate for"
DICT['en.messages.generating_nginx_config_for']="Generating nginx config for"
DICT['en.messages.actual_renewal_job_already_scheduled']="Actual renewal job already scheduled"
DICT['en.messages.schedule_renewal_job']="Schedule renewal SSL certificate cron job"
DICT['en.messages.unschedule_inactual_renewal_job']="Unschedule inactual renewal job"
DICT['en.messages.ssl_enabled_for_domains']="SSL certificates are issued for domains:"
DICT['en.messages.ssl_not_enabled_for_domains']="There were errors while issuing certificates for domains:"
DICT['en.warnings.nginx_config_exists_for_domain']="nginx config already exists"
DICT['en.warnings.certificate_exists_for_domain']="certificate already exists"
DICT['en.warnings.skip_nginx_config_generation']="skipping nginx config generation"
DICT['en.prompts.ssl_agree_tos']="Do you agree with terms of Let's Encrypt Subscriber Agreement?"
DICT['en.prompts.ssl_agree_tos.help']=$(cat <<- END
	Make sure all the domains are already linked to this server in the DNS
	In order to install Let's Encrypt Free SSL certificates for your Keitaro you must agree with terms of Let's Encrypt Subscriber Agreement (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf).
END
)
DICT['en.prompts.ssl_email']='Please enter your email (you can left this field empty)'
DICT['en.prompts.ssl_email.help']='You can obtain SSL certificate with no email address. This is strongly discouraged, because in the event of key loss or LetsEncrypt account compromise you will irrevocably lose access to your LetsEncrypt account. You will also be unable to receive notice about impending expiration or revocation of your certificates.'

DICT['ru.errors.reinstall_keitaro']="Keitaro отконфигурирована неправильно. Пожалуйста выполните перенастройку Keitaro выполнив команду \`${RECONFIGURE_KEITARO_COMMAND_RU}\`"
DICT['ru.errors.reinstall_keitaro_ssl']="Настройки Nginx вашей Keitaro отконфигурированы неправильно. Пожалуйста выполните перенастройку Nginx выполнив команду \`${RECONFIGURE_KEITARO_SSL_COMMAND_RU}\`"
DICT['ru.errors.see_logs']="Журнал выполнения сохранён в ${SCRIPT_LOG}. Пожалуйста запустите \`${SCRIPT_COMMAND}\` после устранения возникших проблем."
DICT['ru.errors.domain_invalid']=":domain: не похож на домен"
DICT['ru.certbot_errors.wrong_a_entry']="Убедитесь что домен верный и что DNS A запись указывает на нужный IP адрес. Если A запись была обновлена недавно, то следует подождать некоторое время."
DICT['ru.certbot_errors.too_many_requests']="Было слишком много запросов, см. https://letsencrypt.org/docs/rate-limits/"
DICT['ru.certbot_errors.unknown_error']="Во время выпуска сертификата произошла неизвестная ошибка. Пожалуйста, обратитесь в службу поддержки"
DICT['ru.messages.check_renewal_job_scheduled']="Проверяем наличие cron задачи обновления сертификатов"
DICT['ru.messages.check_inactual_renewal_job_scheduled']="Проверяем наличие неактуальной cron задачи"
DICT['ru.messages.make_ssl_cert_links']="Создаются ссылки на SSL сертификаты"
DICT['ru.messages.requesting_certificate_for']="Запрос сертификата для"
DICT['ru.messages.generating_nginx_config_for']="Генерация конфигурации для"
DICT['ru.messages.actual_renewal_job_already_scheduled']="Актуальная cron задача обновления сертификатов уже существует"
DICT['ru.messages.schedule_renewal_job']="Добавляется cron задача обновления сертификатов"
DICT['ru.messages.unschedule_inactual_renewal_job']="Удаляется неактуальная cron задача обновления сертификатов"
DICT['ru.messages.ssl_enabled_for_domains']="SSL сертификаты выпущены для сайтов:"
DICT['ru.messages.ssl_not_enabled_for_domains']="SSL сертификаты не выпущены для сайтов:"
DICT['ru.warnings.nginx_config_exists_for_domain']="nginx конфигурация уже существует"
DICT['ru.warnings.certificate_exists_for_domain']="сертификат уже существует"
DICT['ru.warnings.skip_nginx_config_generation']="пропускаем генерацию конфигурации nginx"
DICT['ru.prompts.ssl_agree_tos']="Вы согласны с условиями Абонентского Соглашения Let's Encrypt?"
DICT['ru.prompts.ssl_agree_tos.help']=$(cat <<- END
	Убедитесь, что все указанные домены привязаны к этому серверу в DNS.
	Для получения бесплатных SSL сертификатов Let's Encrypt вы должны согласиться с условиями Абонентского Соглашения Let's Encrypt (https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf)."
END
)
DICT['ru.prompts.ssl_email']='Укажите email (можно не указывать)'
DICT['ru.prompts.ssl_email.help']='Вы можете получить SSL сертификат без указания email адреса. Однако LetsEncrypt настоятельно рекомендует указать его, так как в случае потери ключа или компрометации LetsEncrypt аккаунта вы полностью потеряете доступ к своему LetsEncrypt аккаунту. Без email вы также не сможете получить уведомление о предстоящем истечении срока действия или отзыве сертификата'
