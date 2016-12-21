require 'spec_helper'

require 'open3'
require 'tmpdir'

RSpec.describe 'installer.sh' do
  let(:args) { '' }
  let(:env) { {} }

  let(:license_ip) { '8.8.8.8' }
  let(:license_key) { 'WWWW-XXXX-YYYY-ZZZZ' }
  let(:db_name) { 'keitarodb' }
  let(:db_user) { 'keitarodb_user' }
  let(:db_password) { 'keitarodb_password' }
  let(:admin_login) { 'admin' }
  let(:admin_password) { 'admin_password' }

  let(:en_prompts_with_values) do
    {
      'Please enter server IP > ' => license_ip,
      'Please enter license key > ' => license_key,
      'Please enter database name > ' => db_name,
      'Please enter database user name > ' => db_user,
      'Please enter database user password > ' => db_password,
      'Please enter keitaro admin login > ' => admin_login,
      'Please enter keitaro admin password > ' => admin_password,
    }
  end

  let(:ru_prompts_with_values) do
    {
      'Укажите IP адрес сервера > ' => license_ip,
      'Укажите лицензионный ключ > ' => license_key,
      'Укажите имя базы данных > ' => db_name,
      'Укажите пользователя базы данных > ' => db_user,
      'Укажите пароль пользователя базы данных > ' => db_password,
      'Укажите имя администратора keitaro > ' => admin_login,
      'Укажите пароль администратора keitaro > ' => admin_password,
    }
  end

  let(:prompts_with_values) { en_prompts_with_values }

  let(:installer) { Installer.new(env: env, args: args, prompts_with_values: prompts_with_values) }

  shared_examples_for 'should print to stdout' do |expected_text|
    before { installer.call }
    specify { expect(installer.stdout).to match(expected_text) }
  end

  shared_examples_for 'should exit with error' do |expected_text|
    it 'exits with error' do
      installer.call
      expect(installer.ret_value).not_to be_success
      expect(installer.stderr).to match(expected_text)
    end
  end

  describe 'invoked' do
    context 'with wrong args' do
      let(:args) { '-x' }

      it_behaves_like 'should exit with error', "Usage: #{Installer::INSTALLER_CMD}"
    end

    context 'with `-v` args' do
      let(:args) { '-v' }

      it_behaves_like 'should print to stdout', 'Verbose mode: on'
    end

    context 'with `-l` option' do
      let(:env) { {LANG: 'C'} }
      let(:args) { "-v -l #{lang}" }

      context 'with `en` value' do
        let(:lang) { 'en' }

        it_behaves_like 'should print to stdout', 'Language: en'
      end

      context 'with `ru` value' do
        let(:lang) { 'ru' }

        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'with unsupported value' do
        let(:lang) { 'xx' }

        it_behaves_like 'should exit with error', 'Specified language "xx" is not supported'
      end
    end

    # TODO: Detect from LC_MESSAGES
    describe 'detects language from LANG environment variable' do
      let(:args) { '-v' } # Switch on verbose mode for testing purposes

      context 'LANG=ru_RU.UTF-8' do
        let(:env) { {LANG: 'ru_RU.UTF-8'} }

        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'LANG=ru_UA.UTF-8' do
        let(:env) { {LANG: 'ru_UA.UTF-8'} }

        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'LANG=en_US.UTF-8' do
        let(:env) { {LANG: 'en_US.UTF-8'} }

        it_behaves_like 'should print to stdout', 'Language: en'
      end

      context 'LANG=de_DE.UTF-8' do
        let(:env) { {LANG: 'de_DE.UTF-8'} }

        it_behaves_like 'should print to stdout', 'Language: en'
      end
    end
  end

  context 'without actual yum/ansible checks, without actual invoking install commands' do
    # `-s` option disables yum/ansible checks
    # `-p` option disables invoking install commands

    describe 'generated hosts file' do
      shared_examples_for 'contains correct entries' do
        before { installer.call }

        let(:hosts_file_content) { File.read('.keitarotds-hosts') }

        it 'contains license_ip key' do
          expect(hosts_file_content).to match(%Q{\nlicense_ip = "#{license_ip}"\n})
        end

        it 'contains license_key key' do
          expect(hosts_file_content).to match(%Q{\nlicense_key = "#{license_key}"\n})
        end

        it 'contains db_name key' do
          expect(hosts_file_content).to match(%Q{\ndb_name = "#{db_name}"\n})
        end
        it 'contains db_user key' do
          expect(hosts_file_content).to match(%Q{\ndb_user = "#{db_user}"\n})
        end

        it 'contains db_password key' do
          expect(hosts_file_content).to match(%Q{\ndb_password = "#{db_password}"\n})
        end

        it 'contains admin_login key' do
          expect(hosts_file_content).to match(%Q{\nadmin_login = "#{admin_login}"\n})
        end

        it 'contains admin_password key' do
          expect(hosts_file_content).to match(%Q{\nadmin_password = "#{admin_password}"\n})
        end
      end

      context 'english prompts' do
        let(:args) { '-sp -l en' }
        let(:prompts_with_values) { en_prompts_with_values }

        it_behaves_like 'contains correct entries'
      end

      context 'russian prompts' do
        let(:args) { '-sp -l ru' }
        let(:prompts_with_values) { ru_prompts_with_values }

        it_behaves_like 'contains correct entries'
      end
    end
  end
end
