require 'spec_helper'

RSpec.describe 'enable-ssl.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:script_name) { 'enable-ssl.sh' }
  let(:args) { options + ' ' + domains.join(' ') }
  let(:emulate_crontab) do
    [
      %q(echo "if [[ \\"\\$2\\" != nginx ]]; then echo certbot renew; fi; if [[ \\${@:\\$#} == '-' ]]; then read -t 1; fi"  > /bin/crontab),
      'chmod a+x /bin/crontab'
    ]
  end
  let(:all_command_stubs) { {nginx: '/bin/true', certbot: '/bin/true', crontab: '/bin/true', chown: '/bin/true'} }
  let(:domains) { %w[domain1.tld] }
  let(:nginx_conf) {
    <<-END
    server {
      listen 80 default_server;
      server_name _;
      listen 443 ssl;

      ssl_certificate /etc/nginx/ssl/cert.pem;
      ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    }
    END
  }

  let(:make_proper_nginx_conf) do
    [
      'mkdir -p /etc/nginx/conf.d /etc/nginx/ssl',
      'touch /etc/nginx/ssl/{cert,privkey}.pem',
      %Q{echo -e "#{nginx_conf}"> /etc/nginx/conf.d/keitaro.conf}
    ]
  end

  let(:make_keitaro_inventory) do
    [
      %Q{echo -e "installer_version=#{Inventory::SERVER_CONFIGURATION_VERSION}"> /root/.keitaro}
    ]
  end

  let(:prompts) do
    {
      en: {
        ssl_agree_tos: "Do you agree with terms of Let's Encrypt Subscriber Agreement?",
        ssl_email: 'Please enter your email (you can left this field empty)',
      },
      ru: {
        ssl_agree_tos: "Вы согласны с условиями Абонентского Соглашения Let's Encrypt?",
        ssl_email: 'Укажите email (можно не указывать)',
      }
    }
  end

  let(:user_values) do
    {
      ssl_agree_tos: 'yes',
      ssl_email: '',
    }
  end

  it_behaves_like 'should try to detect bash pipe mode'

  describe 'should print usage if invoked with wrong args' do
    it_behaves_like 'should print usage when invoked with', args: '-s -x domain1.tld'
  end

  describe 'should print usage if invoked with domains seaprated by comma' do
    it_behaves_like 'should print usage when invoked with', args: '-s -x domain1.tld,domain2.tld'
  end

  describe 'should print usage if invoked without domains' do
    it_behaves_like 'should print usage when invoked with', args: '-s'
  end

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

  describe 'fields' do
    # `-s` option disables cerbot/nginx conf checks
    # `-p` option disables invoking certbot command

    let(:options) { '-s -p -l en' }

    it_behaves_like 'should show default value', :ssl_agree_tos, showed_value: 'yes'

    it_behaves_like 'should not show default value', :ssl_email
  end

  context 'without actual running commands' do
    include_context 'run in docker'

    let(:commands) { make_keitaro_inventory }

    let(:options) { '-p' }

    shared_examples_for 'should enable ssl for Keitaro' do
      it_behaves_like 'should print to', :log, 'certbot certonly --webroot'
    end

    context 'nginx is installed, certbot is installed, crontab is installed, nginx is configured properly' do

      let(:command_stubs) { all_command_stubs }

      let(:commands) { make_proper_nginx_conf + make_keitaro_inventory }

      it_behaves_like 'should print to', :log, [
        "Try to found nginx\nFOUND",
        "Try to found crontab\nFOUND",
        "Try to found certbot\nFOUND",
        "Checking /etc/nginx/conf.d/keitaro.conf file existence\nYES",
        "Checking ssl params in /etc/nginx/conf.d/keitaro.conf\nOK"
      ]

      it_behaves_like 'should enable ssl for Keitaro'
    end

    context 'nginx is not installed' do
      let(:command_stubs) { {crontab: '/bin/true'} }

      it_behaves_like 'should print to', :log, "Try to found nginx\nNOT FOUND"

      it_behaves_like 'should exit with error', 'Your Keitaro installation does not properly configured'
    end

    context 'crontab is not installed' do
      let(:command_stubs) { {nginx: '/bin/true', certbot: '/bin/true'} }

      it_behaves_like 'should print to', :log, "Try to found crontab\nNOT FOUND"

      it_behaves_like 'should exit with error', 'Your Keitaro installation does not properly configured'
    end

    context 'certbot is not installed' do
      let(:command_stubs) { {nginx: '/bin/true', crontab: '/bin/true'} }

      it_behaves_like 'should print to', :log, "Try to found certbot\nNOT FOUND"

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro installation does not properly configured'
    end

    context 'certbot is installed, keitaro.conf is absent' do
      let(:command_stubs) { all_command_stubs }

      it_behaves_like 'should print to', :log, [
        "Try to found certbot\nFOUND",
        "Checking /etc/nginx/conf.d/keitaro.conf file existence\nNO",
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro installation does not properly configured'
    end

    context 'programs are installed, nginx is not configured properly' do
      let(:command_stubs) { all_command_stubs }

      let(:nginx_conf) { "listen 80;" }

      let(:commands) { make_proper_nginx_conf + make_keitaro_inventory }

      it_behaves_like 'should print to', :log, [
        "Try to found certbot\nFOUND",
        "Checking /etc/nginx/conf.d/keitaro.conf file existence\nYES",
        "Checking ssl params in /etc/nginx/conf.d/keitaro.conf\nERROR"
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro installation does not properly configured'
    end
  end

  describe 'enable-ssl result' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + make_keitaro_inventory }

    context 'successful running certbot' do
      let(:commands) { make_proper_nginx_conf + emulate_crontab + make_keitaro_inventory }

      it_behaves_like 'should print to', :stdout, /Everything is done!/
    end
  end

  context 'with agree LE SA option specified' do
    let(:options) { '-s -p -a' }

    it_behaves_like 'should not print to', :stdout, "Do you agree with terms of Let's Encrypt Subscriber Agreement?"

    it_behaves_like 'should print to', :stdout, 'Everything is done!'
  end

  context 'email specified' do
    let(:options) { '-s -p -e some.mail@example.com' }

    it_behaves_like 'should not print to', :stdout, 'Please enter your email'

    it_behaves_like 'should print to', :log, /certbot certonly .* --email some.mail@example.com/
  end

  context 'without email option specified' do
    let(:options) { '-s -p -w' }

    it_behaves_like 'should not print to', :stdout, 'Please enter your email'

    it_behaves_like 'should print to', :log, /certbot certonly .* --register-unsafely-without-email/
  end

  describe 'adding cron task' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + make_keitaro_inventory }

    it_behaves_like 'should print to', :log, /Schedule renewal job/

    context 'relevant cron job already scheduled' do
      let(:commands) { make_proper_nginx_conf + emulate_crontab + make_keitaro_inventory }

      it_behaves_like 'should print to', :log, /Renewal cron job already scheduled/
    end
  end

  describe 'reloading nginx' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to', :log, /nginx -s reload/
  end


  describe 'run certbot for each specified doamin' do
    let(:options) { '-s -p' }
    let(:domains) { %w[d1.com d2.com] }

    it_behaves_like 'should print to', :log,
                    /certbot .* --non-interactive --domain d1.com --register-unsafely-without-email/

    it_behaves_like 'should print to', :log,
                    /certbot .* --non-interactive --domain d2.com --register-unsafely-without-email/
  end


  describe 'generates nginx config' do
    let(:command_stubs) { all_command_stubs }
    let(:docker_image) { 'centos' }
    let(:commands) { make_proper_nginx_conf + emulate_crontab + make_keitaro_inventory }
    let(:save_files) { %w[/etc/nginx/conf.d/domain1.tld.conf] }

    it 'domain1.tld.conf file should be properly configured' do
      run_script
      content = File.read("#{@current_dir}/domain1.tld.conf")
      expect(content).to match('server_name domain1.tld;')
      expect(content).to match('ssl_certificate /etc/letsencrypt/live/domain1.tld/fullchain.pem;')
      expect(content).to match('ssl_certificate_key /etc/letsencrypt/live/domain1.tld/privkey.pem;')
    end
  end

  context 'certs already point to letsencrypt certs' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }

    let(:domains) { %w[d3.com d4.com] }
    let(:extra_commands) { [] }
    let(:commands) do
      [
        'mkdir -p /etc/letsencrypt/live/d1.com /etc/nginx/conf.d /etc/nginx/ssl',
        'touch /etc/letsencrypt/live/d1.com/{cert,privkey}.pem',
        'ln -s /etc/letsencrypt/live/d1.com/cert.pem /etc/nginx/ssl/cert.pem',
        'ln -s /etc/letsencrypt/live/d1.com/privkey.pem /etc/nginx/ssl/privkey.pem',
        %q(echo "echo \\"    DNS:d1.com, DNS:d2.com\\"" > /bin/openssl),
        'chmod a+x /bin/openssl',
      ] + make_proper_nginx_conf + emulate_crontab + extra_commands + make_keitaro_inventory
    end

    it_behaves_like 'should print to', :log, ['Requesting certificate for domain d1.com',
                                              'Requesting certificate for domain d2.com',
                                              'Requesting certificate for domain d3.com',
                                              'Requesting certificate for domain d4.com']


    it_behaves_like 'should print to', :log, ['Generating nginx config for d1.com',
                                              'Generating nginx config for d2.com',
                                              'Generating nginx config for d3.com',
                                              'Generating nginx config for d4.com']

    context 'certificate for domain d3.com already exists' do
      let(:extra_commands) { ['mkdir -p /etc/letsencrypt/live/d3.com'] }

      it_behaves_like 'should not print to', :log, 'Requesting certificate for domain d3.com'

      it_behaves_like 'should print to', :log, 'Generating nginx config for d3.com'
    end

    context 'nginx config for domain d3.com already exists' do
      let(:extra_commands) { ['touch /etc/nginx/conf.d/d3.com.conf'] }

      it_behaves_like 'should print to', :log, ['Requesting certificate for domain d3.com',
                                                'Saving old nginx config for d3.com',
      ]
      # 'Generating nginx config for d3.com']

      it_behaves_like 'should print to', :stdout,
                      'SSL certificates are issued for domains: d1.com, d2.com, d3.com, d4.com'

      it_behaves_like 'should not print to', :stdout,
                      'SSL certificates are not issued'
    end

    describe 'tries to issue certificate for all domains, even on requesting error' do
      let(:command_stubs) { all_command_stubs.merge(certbot: '/bin/false') }


      it_behaves_like 'should print to', :log, ['Requesting certificate for domain d1.com',
                                                'Requesting certificate for domain d2.com',
                                                'Requesting certificate for domain d3.com',
                                                'Requesting certificate for domain d4.com']

      it_behaves_like 'should not print to', :log, ['Generating nginx config for d1.com',
                                                    'Generating nginx config for d2.com',
                                                    'Generating nginx config for d3.com',
                                                    'Generating nginx config for d4.com']

      it_behaves_like 'should not print to', :stdout, 'SSL certificates are issued'

      it_behaves_like 'should print to', :stdout,
                      /NOK. There were errors.*: d1.com, d2.com, d3.com, d4.com/
    end

    describe 'correctly recognizes errors' do
      let(:extra_commands) do
        [
          "cp #{Script::DOCKER_SCRIPTS_DIR}/spec/files/certbot/#{error} /bin/certbot",
          "chmod a+x /bin/certbot"
        ]
      end
      let(:command_stubs) { all_command_stubs }
      let(:domains) { %w[domain.tld] }

      context 'no A entry' do
        let(:error) { 'no_a_entry' }

        it_behaves_like 'should print to', :stdout,
                        "domain.tld: Please make sure that your domain name was entered correctly"
      end

      context 'too many requests' do
        let(:error) { 'too_many_requests' }

        it_behaves_like 'should print to', :stdout,
                        "domain.tld: There were too many requests"
      end

      context 'unknown error' do
        let(:error) { 'unknown_error' }

        it_behaves_like 'should print to', :stdout,
                        "domain.tld: There was unknown error"
      end
    end
  end
end

