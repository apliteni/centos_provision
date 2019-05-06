require 'spec_helper'

RSpec.describe 'enable-ssl.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:script_name) { 'enable-ssl.sh' }
  let(:args) { options }
  let(:emulate_crontab) do
    [
      %q(echo "if [[ \\"\\$2\\" != nginx ]]; then echo certbot renew; fi; if [[ \\${@:\\$#} == '-' ]]; then read -t 1; fi"  > /bin/crontab),
      'chmod a+x /bin/crontab'
    ]
  end
  let(:all_command_stubs) { {nginx: '/bin/true', certbot: '/bin/true', crontab: '/bin/true', chown: '/bin/true'} }
  let(:nginx_conf) {
    <<-END
    server {
      listen 80 default_server;
      server_name _;
      listen 443 ssl;

      ssl_certificate /etc/keitaro/ssl/cert.pem;
      ssl_certificate_key /etc/keitaro/ssl/privkey.pem;
    }
    END
  }

  let(:make_proper_nginx_conf) do
    [
      'mkdir -p /etc/nginx/conf.d/local/keitaro /etc/nginx/keitaro /etc/keitaro/ssl',
      'touch /etc/keitaro/ssl/{cert,privkey}.pem',
      %Q{echo -e "#{nginx_conf}"> /etc/nginx/conf.d/keitaro.conf}
    ]
  end

  let(:prompts) do
    {
      en: {ssl_domains: 'Please enter domains separated by comma without spaces'},
      ru: {ssl_domains: 'Укажите список доменов через запятую без пробелов'}
    }
  end

  let(:user_values) do
    {ssl_domains: ssl_domains}
  end

  let(:ssl_domains) { 'd1.com' }

  it_behaves_like 'should try to detect bash pipe mode'

  describe 'should print usage if invoked with wrong args' do
    it_behaves_like 'should print usage when invoked with', args: '-x'
  end

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

  describe 'fields' do
    # `-s` option disables cerbot/nginx conf checks
    # `-p` option disables invoking certbot command

    let(:options) { '-s -p -L en' }

    it_behaves_like 'should not show default value', :ssl_domains
  end

  context 'without actual running commands' do
    include_context 'run in docker'

    let(:commands) { [] }

    let(:options) { '-p' }

    shared_examples_for 'should enable ssl for Keitaro' do
      it_behaves_like 'should print to', :log, 'certbot certonly --webroot'
    end
  end

  describe 'enable-ssl result' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf }

    context 'successful running certbot' do
      let(:commands) { make_proper_nginx_conf + emulate_crontab }

      it_behaves_like 'should print to', :stdout, /Everything is done!/

      it_behaves_like 'should print to', :log, /certbot certonly .* --domain d1.com --register-unsafely-without-email/
    end
  end

  describe 'adding cron task' do
    let(:docker_image) { 'centos' }

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf }

    it_behaves_like 'should print to', :log, /Schedule renewal job/

    context 'relevant cron job already scheduled' do
      let(:commands) { make_proper_nginx_conf + emulate_crontab }

      it_behaves_like 'should print to', :log, /Renewal cron job already scheduled/
    end
  end

  describe 'reloading nginx' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to', :log, /nginx -s reload/
  end


  describe 'run certbot for each specified doamin' do
    let(:options) { '-sp' }

    let(:ssl_domains) { 'd1.com,d2.com' }

    it_behaves_like 'should print to', :log,
                    /certbot .* --non-interactive --domain d1.com --register-unsafely-without-email/

    it_behaves_like 'should print to', :log,
                    /certbot .* --non-interactive --domain d2.com --register-unsafely-without-email/
  end


  describe 'generating nginx config' do
    let(:docker_image) { 'centos' }

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + emulate_crontab }

    let(:save_files) { %w[/etc/nginx/conf.d/d1.com.conf] }

    it 'd1.com.conf file should be properly configured' do
      run_script
      content = File.read("#{@current_dir}/d1.com.conf")
      expect(content).to match('server_name d1.com;')
      expect(content).to match('ssl_certificate /etc/letsencrypt/live/d1.com/fullchain.pem;')
      expect(content).to match('ssl_certificate_key /etc/letsencrypt/live/d1.com/privkey.pem;')
    end
  end

  describe 'generating configs' do
    include_context 'run in docker'

    let(:ssl_domains) { 'd1.com,d2.com' }
    let(:command_stubs) { all_command_stubs }

    let(:commands) { make_proper_nginx_conf + emulate_crontab + extra_commands }
    let(:extra_commands) { [] }

    context 'certificate for domain d1.com already exists' do
      let(:extra_commands) { ['mkdir -p /etc/letsencrypt/live/d1.com'] }

      it_behaves_like 'should not print to', :log, 'Requesting certificate for domain d1.com'

      it_behaves_like 'should print to', :log, 'Generating nginx config for d1.com'
    end

    context 'nginx config for domain d1.com already exists' do
      let(:extra_commands) { ['touch /etc/nginx/conf.d/d1.com.conf'] }

      it_behaves_like 'should print to', :log,
                      ['Requesting certificate for domain d1.com',
                       'File /etc/nginx/conf.d/d1.com.conf generated by irrelevant installer tool, force regenerating',
                       'Generating nginx config for d1.com',
                       'Requesting certificate for domain d2.com',
                       'File /etc/nginx/conf.d/d2.com.conf does not exist, force generating',
                       'Generating nginx config for d2.com']

      it_behaves_like 'should print to', :stdout,
                      'SSL certificates are issued for domains: d1.com, d2.com'

      it_behaves_like 'should not print to', :stdout,
                      'SSL certificates are not issued'
    end

    describe 'tries to issue certificate for all domains, even on requesting error' do
      let(:command_stubs) { all_command_stubs.merge(certbot: '/bin/false') }


      it_behaves_like 'should print to', :log, ['Requesting certificate for domain d1.com',
                                                'Requesting certificate for domain d2.com']

      it_behaves_like 'should not print to', :log, ['Generating nginx config for d1.com',
                                                    'Generating nginx config for d2.com']

      it_behaves_like 'should not print to', :stdout, 'SSL certificates are issued'

      it_behaves_like 'should print to', :stdout,
                      /NOK. There were errors.*: d1.com, d2.com/
    end

    describe 'correctly recognizes errors' do
      let(:extra_commands) do
        [
          "cp #{Script::DOCKER_SCRIPTS_DIR}/spec/files/certbot/#{error} /bin/certbot",
          'chmod a+x /bin/certbot'
        ]
      end

      let(:command_stubs) { all_command_stubs }

      context 'no A entry' do
        let(:error) { 'no_a_entry' }

        it_behaves_like 'should print to', :stdout,
                        'd1.com: Please make sure that your domain name was entered correctly'
      end

      context 'too many requests' do
        let(:error) { 'too_many_requests' }

        it_behaves_like 'should print to', :stdout,
                        'd1.com: There were too many requests'
      end

      context 'unknown error' do
        let(:error) { 'unknown_error' }

        it_behaves_like 'should print to', :stdout,
                        'd1.com: There was unknown error'
      end
    end
  end

  describe 'should run obsolete enable-ssl for old versions' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:remove_inventory) { ['rm -rf .keitaro'] }
    let(:commands) { make_proper_nginx_conf + emulate_crontab + remove_inventory }

    it_behaves_like 'should print to', :stdout, 'Run obsolete enable-ssl (v0.9)'
  end
end

