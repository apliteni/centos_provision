require 'spec_helper'

RSpec.describe 'add-site.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:script_name) { 'add-site.sh' }
  let(:all_command_stubs) { {nginx: '/bin/true', certbot: '/bin/true', crontab: '/bin/true'} }
  let(:nginx_conf) { "ssl_certificate /etc/nginx/cert.pem;\nssl_certificate_key /etc/nginx/ssl/privkey.pem;" }
  let(:make_proper_nginx_conf) do
    [
      'mkdir -p /etc/nginx/conf.d',
      %Q{echo -e "#{nginx_conf}"> /etc/nginx/conf.d/vhosts.conf}
    ]
  end

  let(:prompts) do
    {
      en: {
        site_domains: 'Please enter domain name',
        site_root: 'Please enter your site root directory',
      },
      ru: {
        site_domains: 'Укажите доменное имя сайта',
        site_root: 'Укажите корневую директорию сайта',
      }
    }
  end

  let(:user_values) do
    {
      site_domains: 'example.com',
      site_root: '',
    }
  end

  it_behaves_like 'should try to detect bash pipe mode'
  it_behaves_like 'should print usage when invoked with', '-s -x'
  it_behaves_like 'should detect language'

  describe 'fields' do
    # `-s` option disables cerbot/nginx conf checks
    # `-p` option disables invoking certbot command

    let(:options) { '-spl en' }

    describe 'should support russian prompts' do
      let(:options) { '-sp -l ru' }
      let(:prompts_with_values) { make_prompts_with_values(:ru) }

      it 'stdout contains prompt with default value' do
        run_script
        expect(site_adder.stdout).to include(prompts[:ru][:ssl_agree_tos])
      end
    end

    describe 'should show default value' do
      it 'stdout contains prompt with default value' do
        run_script
        expect(site_adder.stdout).to include("#{prompts[:en][:ssl_agree_tos]} [no] >")
      end
    end
  end

  context 'without actual running commands' do
    let(:options) { '-p' }

    before(:all) { `docker rm keitaro_site_adder_test &>/dev/null` }

    shared_examples_for 'should enable ssl for Keitaro TDS' do
      it_behaves_like 'should print to stdout', 'certbot certonly --webroot'
    end

    context 'nginx is installed, keitaro is installed, nginx is configured properly' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { all_command_stubs }

      let(:commands) { make_proper_nginx_conf }

      it_behaves_like 'should print to log', [
        "Try to found nginx\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf file existence\nOK",
        "Checking /var/www/keitaro/ directory existence\nOK",
        "Checking params in /etc/nginx/conf.d/vhosts.conf\nOK"
      ]

      it_behaves_like 'should enable ssl for Keitaro TDS'
    end

    context 'nginx is not installed' do
      let(:docker_image) { 'centos' }

      it_behaves_like 'should print to log', "Try to found nginx\nNOK"

      it_behaves_like 'should exit with error', 'Your Keitaro TDS installation does not properly configured'
    end

    context 'keitaro is not installed' do
      let(:docker_image) { 'centos' }
      let(:command_stubs) { {nginx: '/bin/true', crontab: '/bin/true'} }

      it_behaves_like 'should print to log', "Try to found certbot\nNOK"

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end

    context 'certbot is installed, vhosts.conf is absent' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { all_command_stubs }

      it_behaves_like 'should print to log', [
        "Try to found certbot\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf file existence\nNOK",
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end

    context 'programs are installed, nginx is not configured properly' do
      let(:docker_image) { 'centos' }
      let(:command_stubs) { all_command_stubs }

      let(:nginx_conf) { "listen 80;" }

      let(:commands) { make_proper_nginx_conf }

      it_behaves_like 'should print to log', [
        "Try to found certbot\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf file existence\nOK",
        "Checking ssl params in /etc/nginx/conf.d/vhosts.conf\nNOK"
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end
  end

  describe 'add-site result' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + emulate_sudo }

    context 'successful running certbot' do
      it_behaves_like 'should print to stdout', /Everything done!/
    end

    context 'unsuccessful running certbot' do
      let(:command_stubs) { all_command_stubs.merge(certbot: '/bin/false') }

      it_behaves_like 'should exit with error', [
                                                  'There was an error evaluating command `certbot',
                                                  'Evaluating log saved to add-site.log',
                                                  'Please rerun `add-site.sh domain1.tld`'
                                                ]
    end
  end

  describe 'run certbot as nginx' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + emulate_sudo }

    it_behaves_like 'should print to log', "sudo -u 'nginx' bash -c 'certbot"

  end

  context 'with agree LE SA option specified' do
    let(:options) { '-s -p -a' }

    it_behaves_like 'should not print to stdout', "Do you agree with terms of Let's Encrypt Subscriber Agreement?"

    it_behaves_like 'should print to stdout', 'Everything done!'
  end

  context 'email specified' do
    let(:options) { '-s -p -e some.mail@example.com' }

    it_behaves_like 'should not print to stdout', 'Please enter your email'

    it_behaves_like 'should print to stdout', /certbot certonly .* --email some.mail@example.com/
  end

  context 'without email option specified' do
    let(:options) { '-s -p -w' }

    it_behaves_like 'should not print to stdout', 'Please enter your email'

    it_behaves_like 'should print to stdout', /certbot certonly .* --register-unsafely-without-email/
  end

  describe 'check running under non-root' do
    it_behaves_like 'should exit with error', 'You must run this program as root'
  end

  describe 'making symlinks' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to log', 'rm -f /etc/nginx/ssl/cert.pem'
    it_behaves_like 'should print to log', 'ln -s /etc/letsencrypt/live/domain1.tld/fullchain.pem /etc/nginx/ssl/cert.pem'
    it_behaves_like 'should print to log', 'rm -f /etc/nginx/ssl/privkey.pem'
    it_behaves_like 'should print to log', 'ln -s /etc/letsencrypt/live/domain1.tld/privkey.pem /etc/nginx/ssl/privkey.pem'
  end

  describe 'logging' do
    shared_examples_for 'should create' do |filename|
      specify do
        run_script
        expect(File).to be_exists(filename)
      end
    end

    shared_examples_for 'should move old add-site.log to' do |newname|
      specify do
        old_content = IO.read('add-site.log')
        run_script
        expect(IO.read(newname)).to eq(old_content)
      end
    end

    context 'log files does not exists' do
      it_behaves_like 'should create', 'add-site.log'
    end

    context 'add-site.log exists' do
      before { IO.write('add-site.log', 'some log') }

      it_behaves_like 'should create', 'add-site.log'

      it_behaves_like 'should move old add-site.log to', 'add-site.log.1'
    end

    context 'add-site.log, add-site.log.1 exists' do
      before { IO.write('add-site.log', 'some log') }
      before { IO.write('add-site.log.1', 'some log.1') }

      it_behaves_like 'should create', 'add-site.log'

      it_behaves_like 'should move old add-site.log to', 'add-site.log.2'
    end
  end

  describe 'reloading nginx' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to log', /nginx -s reload/
  end
end
