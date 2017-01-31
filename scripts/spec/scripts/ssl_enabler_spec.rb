require 'spec_helper'

RSpec.describe 'ssl_enabler.sh' do
  let(:options) { '' }
  let(:args) { options + ' ' + domains.join(' ') }
  let(:env) { {} }
  let(:docker_image) { nil }
  let(:command_stubs) { {} }
  let(:domains) { %w[domain1.tld] }

  let(:prompts) do
    {
      en: {
        ssl_agree_tos: "Do you agree with terms of Let's Encrypt Subscriber Agreement?",
      },
      ru: {
        ssl_agree_tos: "Вы согласны с условиями Абонентского Соглашения Let's Encrypt?"
      }
    }
  end

  let(:user_values) do
    {
      ssl_agree_tos: 'yes',
    }
  end

  let(:en_prompts_with_values) do
    {
      prompts[:en][:ssl_agree_tos] => user_values[:ssl_agree_tos],
    }
  end

  let(:ru_prompts_with_values) do
    {
      prompts[:ru][:ssl_agree_tos] => user_values[:ssl_agree_tos],
    }
  end

  let(:prompts_with_values) { en_prompts_with_values }

  let(:ssl_enabler) do
    SslEnabler.new env: env,
                  args: args,
                  prompts_with_values: prompts_with_values,
                  docker_image: docker_image,
                  command_stubs: command_stubs
  end

  shared_examples_for 'should print to log' do |expected_text|
    it "prints to stdout #{expected_text.inspect}" do
      ssl_enabler.call(current_dir: @current_dir)
      expect(ssl_enabler.log).to match(expected_text)
    end
  end

  shared_examples_for 'should print to stdout' do |expected_text|
    it "prints to stdout #{expected_text.inspect}" do
      ssl_enabler.call
      expect(ssl_enabler.stdout).to match(expected_text)
    end
  end

  shared_examples_for 'should not print to stdout' do |expected_text|
    it "does not print to stdout #{expected_text.inspect}" do
      ssl_enabler.call
      expect(ssl_enabler.stdout).not_to match(expected_text)
    end
  end

  shared_examples_for 'should exit with error' do |expected_text|
    it 'exits with error' do
      ssl_enabler.call
      expect(ssl_enabler.ret_value).not_to be_success
      expect(ssl_enabler.stderr).to match(expected_text)
    end
  end

  describe 'invoked' do
    context 'with wrong options' do
      let(:env) { {LANG: 'C'} }
      let(:options) { '-x' }

      it_behaves_like 'should exit with error', "Usage: #{SslEnabler::SSL_ENABLER_CMD}"
    end

    context 'without domains' do
      let(:env) { {LANG: 'C'} }

      let(:domains) { [] }

      it_behaves_like 'should exit with error', "Usage: #{SslEnabler::SSL_ENABLER_CMD}"
    end

    context 'with `-l` option' do
      let(:env) { {LANG: 'C'} }
      let(:options) { "-l #{lang}" }

      context 'with `en` value' do
        let(:lang) { 'en' }

        it_behaves_like 'should print to log', 'Language: en'
      end

      context 'with `ru` value' do
        let(:lang) { 'ru' }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'with unsupported value' do
        let(:lang) { 'xx' }

        it_behaves_like 'should exit with error', 'Specified language "xx" is not supported'
      end
    end

    # TODO: Detect language from LC_MESSAGES
    describe 'detects language from LANG environment variable' do
      context 'LANG=ru_RU.UTF-8' do
        let(:env) { {LANG: 'ru_RU.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'LANG=ru_UA.UTF-8' do
        let(:env) { {LANG: 'ru_UA.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'LANG=en_US.UTF-8' do
        let(:env) { {LANG: 'en_US.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: en'
      end

      context 'LANG=de_DE.UTF-8' do
        let(:env) { {LANG: 'de_DE.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: en'
      end
    end
  end

  describe 'fields' do
    # `-s` option disables cerbot/nginx conf checks
    # `-p` option disables invoking certbot command

    let(:options) { '-spl en' }

    describe 'should support russian prompts' do
      let(:options) { '-sp -l ru' }
      let(:prompts_with_values) { ru_prompts_with_values }

      it 'stdout contains prompt with default value' do
        ssl_enabler.call
        expect(ssl_enabler.stdout).to include(prompts[:ru][:ssl_agree_tos])
      end
    end

    describe 'should show default value' do
      it 'stdout contains prompt with default value' do
        ssl_enabler.call
        expect(ssl_enabler.stdout).to match(/#{prompts[:en][:ssl_agree_tos]} \[no\] >/)
      end
    end
  end

  context 'without actual running commands' do
    let(:env) { {LANG: 'C'} }
    let(:options) { '-p ' }

    before(:all) { `docker rm keitaro_ssl_enabler_test &>/dev/null` }

    shared_examples_for 'should enable ssl for Keitaro TDS' do
      it_behaves_like 'should print to stdout',
                      'certbot certonly --webroot'
    end

    context 'certbot installed, nginx configured properly' do
      let(:docker_image) { 'ansible/centos7-ansible' }

      it_behaves_like 'should print to log', "Try to found certbot\nOK"

      it_behaves_like 'should enable ssl for Keitaro TDS'
    end

    context 'certbot not installed, nginx configured properly' do
      let(:docker_image) { 'centos' }

      it_behaves_like 'should print to log', "Try to found certbot\nNOK"

      it_behaves_like 'should enable ssl for Keitaro TDS'
    end

    context 'certbot installed, nginx not configured properly' do
      let(:docker_image) { 'ubuntu' }

      it_behaves_like 'should print to log', "Try to found yum\nNOK"
      it_behaves_like 'should exit with error', 'This ssl_enabler works only on yum-based systems'
    end
  end

  describe 'enable-ssl result' do
    let(:env) { {LANG: 'C'} }

    let(:docker_image) { 'ansible/centos7-ansible' }

    context 'successful running certbot' do
      let(:command_stubs) { {certbot: '/bin/true'} }

      it_behaves_like 'should print to stdout', /Everything done!/
    end

    context 'unsuccessful running certbot' do
      let(:command_stubs) { {certbot: '/bin/false', tar: '/bin/true', 'ansible-playbook': '/bin/false'} }

      it_behaves_like 'should exit with error', /There was an error evaluating command 'certbot/
      it_behaves_like 'should exit with error', /Running log saved to enable-ssl.log/
      it_behaves_like 'should exit with error', /You can rerun 'enable-ssl.sh'/
    end
  end

  describe 'check running under non-root' do
    let(:env) { {LANG: 'C'} }

    it_behaves_like 'should exit with error', 'You must run this program as root'
  end

  describe 'log files' do
    around do |example|
      Dir.mktmpdir('', '/tmp') do |current_dir|
        Dir.chdir(current_dir) do
          @current_dir = current_dir
          example.run
        end
      end
    end

    shared_examples_for 'should create' do |filename|
      specify do
        ssl_enabler.call(current_dir: @current_dir)
        expect(File).to be_exists(filename)
      end
    end

    shared_examples_for 'should move old enable-ssl.log to' do |newname|
      specify do
        old_content = IO.read('enable-ssl.log')
        ssl_enabler.call(current_dir: @current_dir)
        expect(IO.read(newname)).to eq(old_content)
      end
    end

    context 'log files does not exists' do
      it_behaves_like 'should create', 'enable-ssl.log'
    end

    context 'enable-ssl.log exists' do
      before { IO.write('enable-ssl.log', 'some log') }

      it_behaves_like 'should create', 'enable-ssl.log'

      it_behaves_like 'should move old enable-ssl.log to', 'enable-ssl.log.1'
    end

    context 'enable-ssl.log, enable-ssl.log.1 exists' do
      before { IO.write('enable-ssl.log', 'some log') }
      before { IO.write('enable-ssl.log.1', 'some log.1') }

      it_behaves_like 'should create', 'enable-ssl.log'

      it_behaves_like 'should move old enable-ssl.log to', 'enable-ssl.log.2'
    end
  end
end
