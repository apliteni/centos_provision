require 'spec_helper'

RSpec.describe 'installer.sh' do
  let(:args) { '' }
  let(:env) { {} }
  let(:stored_values) { {} }
  let(:docker_image) { nil }
  let(:command_stubs) { {} }

  let(:license_ip) { '8.8.8.8' }
  let(:license_key) { 'WWWW-XXXX-YYYY-ZZZZ' }
  let(:db_name) { 'keitarodb' }
  let(:db_user) { 'keitarodb_user' }
  let(:db_password) { 'keitarodb_password' }
  let(:admin_login) { 'admin' }
  let(:admin_password) { 'admin_password' }

  let(:prompts) do
    {
      en: {
        ssl: "Do you want to install Free SSL certificates from Let's Encrypt?",
        license_ip: 'Please enter server IP',
        license_key: 'Please enter license key',
        db_name: 'Please enter database name',
        db_user: 'Please enter database user name',
        db_password: 'Please enter database user password',
        admin_login: 'Please enter keitaro admin login',
        admin_password: 'Please enter keitaro admin password'
      },
      ru: {
        ssl: "Вы хотите установить бесплатные SSL сертификаты, предоставляемые Let's Encrypt?",
        license_ip: 'Укажите IP адрес сервера',
        license_key: 'Укажите лицензионный ключ',
        db_name: 'Укажите имя базы данных',
        db_user: 'Укажите пользователя базы данных',
        db_password: 'Укажите пароль пользователя базы данных',
        admin_login: 'Укажите имя администратора keitaro',
        admin_password: 'Укажите пароль администратора keitaro',
      }
    }
  end

  let(:user_values) do
    {
      ssl: 'no',
      license_ip: '8.8.8.8',
      license_key: 'WWWW-XXXX-YYYY-ZZZZ',
      db_name: 'keitarodb',
      db_user: 'keitarodb_user',
      db_password: 'keitarodb_password',
      admin_login: 'admin',
      admin_password: 'admin_password',
    }
  end

  let(:en_prompts_with_values) do
    {
      prompts[:en][:ssl] => user_values[:ssl],
      prompts[:en][:license_ip] => user_values[:license_ip],
      prompts[:en][:license_key] => user_values[:license_key],
      prompts[:en][:db_name] => user_values[:db_name],
      prompts[:en][:db_user] => user_values[:db_user],
      prompts[:en][:db_password] => user_values[:db_password],
      prompts[:en][:admin_login] => user_values[:admin_login],
      prompts[:en][:admin_password] => user_values[:admin_password],
    }
  end

  let(:ru_prompts_with_values) do
    {
      prompts[:ru][:ssl] => user_values[:ssl],
      prompts[:ru][:license_ip] => user_values[:license_ip],
      prompts[:ru][:license_key] => user_values[:license_key],
      prompts[:ru][:db_name] => user_values[:db_name],
      prompts[:ru][:db_user] => user_values[:db_user],
      prompts[:ru][:db_password] => user_values[:db_password],
      prompts[:ru][:admin_login] => user_values[:admin_login],
      prompts[:ru][:admin_password] => user_values[:admin_password],
    }
  end

  let(:prompts_with_values) { en_prompts_with_values }

  let(:installer) do
    Installer.new env: env,
                  args: args,
                  prompts_with_values: prompts_with_values,
                  stored_values: stored_values,
                  docker_image: docker_image,
                  command_stubs: command_stubs
  end

  shared_examples_for 'should print to stdout' do |expected_text|
    it "prints to stdout #{expected_text.inspect}" do
      installer.call
      expect(installer.stdout).to match(expected_text)
    end
  end

  shared_examples_for 'should not print to stdout' do |expected_text|
    it "does not print to stdout #{expected_text.inspect}" do
      installer.call
      expect(installer.stdout).not_to match(expected_text)
    end
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
      let(:env) { {LANG: 'C'} }
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

    # TODO: Detect language from LC_MESSAGES
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

  describe 'fields' do
    # `-s` option disables yum/ansible checks
    # `-p` option disables invoking install commands

    let(:args) { '-spvl en' }

    shared_examples_for 'field without default' do |field|
      context 'field not stored in inventory' do
        it_behaves_like 'should not show default value', field

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user.value'
      end

      it_behaves_like 'should take values from previously saved inventory', field

      it_behaves_like 'should support russian prompts', field
    end

    shared_examples_for 'field with default' do |field, default:|
      context 'field not stored in inventory' do
        it_behaves_like 'should show default value', field, showed_value: default

        it_behaves_like 'should store default value', field, readed_inventory_value: default

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user.value'
      end

      it_behaves_like 'should take values from previously saved inventory', field

      it_behaves_like 'should support russian prompts', field
    end

    shared_examples_for 'password field' do |field|
      context 'field not stored in inventory' do
        it_behaves_like 'should show default value', field, showed_value: /\w{16}/

        it_behaves_like 'should store default value', field, readed_inventory_value: /\w+{16}/

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user.value'
      end

      it_behaves_like 'should take values from previously saved inventory', field

      it_behaves_like 'should support russian prompts', field
    end

    shared_examples_for 'should take values from previously saved inventory' do |field|
      context 'field stored in inventory' do
        let(:stored_values) { {field => 'stored.value'} }

        it_behaves_like 'should show default value', field, showed_value: 'stored.value'

        it_behaves_like 'should store default value', field, readed_inventory_value: 'stored.value'

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user.value'
      end
    end

    shared_examples_for 'should support russian prompts' do |field|
      let(:args) { '-sp -l ru' }
      let(:prompts_with_values) { ru_prompts_with_values }

      it 'stdout contains prompt with default value' do
        installer.call
        expect(installer.stdout).to include(prompts[:ru][field])
      end
    end

    shared_examples_for 'should show default value' do |field, showed_value:|
      it 'stdout contains prompt with default value' do
        installer.call
        expect(installer.stdout).to match(/#{prompts[:en][field]} \[#{showed_value}\] >/)
      end
    end

    shared_examples_for 'should not show default value' do |field|
      it 'stdout does not contain prompt with default value' do
        installer.call
        expect(installer.stdout).to include("#{prompts[:en][field]} >")
      end
    end

    shared_examples_for 'should store default value' do |field, readed_inventory_value:|
      let(:prompts_with_values) { en_prompts_with_values.merge(prompts[:en][field] => nil) }

      it_behaves_like 'inventory contains value', field, readed_inventory_value
    end

    shared_examples_for 'should store user value' do |field, readed_inventory_value:|
      let(:prompts_with_values) { en_prompts_with_values.merge(prompts[:en][field] => readed_inventory_value) }

      it_behaves_like 'inventory contains value', field, readed_inventory_value
    end

    shared_examples_for 'inventory contains value' do |field, value|
      it "inventory file contains field #{field.inspect} with value #{value.inspect}" do
        installer.call
        expect(installer.inventory.values[field]).to match(value)
      end
    end

    it_behaves_like 'field without default', :license_ip

    it_behaves_like 'field without default', :license_key

    it_behaves_like 'field with default', :db_name, default: 'keitaro'

    it_behaves_like 'field with default', :db_user, default: 'keitaro'

    it_behaves_like 'password field', :db_password

    it_behaves_like 'field with default', :admin_login, default: 'admin'

    it_behaves_like 'password field', :admin_password
  end

  context 'without actual installing software' do
    let(:env) { {LANG: 'C'} }
    let(:args) { '-vp' }

    before(:all) { `docker rm keitaro_installer_test &>/dev/null` }

    shared_examples_for 'should install keitarotds' do
      it_behaves_like 'should print to stdout',
                      'curl -sSL https://github.com/keitarocorp/centos_provision/archive/master.tar.gz | tar xz'

      it_behaves_like 'should print to stdout',
                      "ansible-playbook -vvv -i #{Installer::INVENTORY_FILE} centos_provision-master/playbook.yml"
    end

    context 'yum presented, ansible presented' do
      let(:docker_image) { 'ansible/centos7-ansible' }

      it_behaves_like 'should print to stdout', "Try to found yum\nOK"
      it_behaves_like 'should print to stdout', "Try to found ansible\nOK"
      it_behaves_like 'should not print to stdout', 'Execute command: yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum presented, ansible not presented' do
      let(:docker_image) { 'centos' }

      it_behaves_like 'should print to stdout', "Try to found yum\nOK"
      it_behaves_like 'should print to stdout', "Try to found ansible\nNOK"
      it_behaves_like 'should print to stdout', 'yum install -y epel-release'
      it_behaves_like 'should print to stdout', 'yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum not presented' do
      let(:docker_image) { 'ubuntu' }

      it_behaves_like 'should print to stdout', "Try to found yum\nNOK"
      it_behaves_like 'should exit with error', 'This installer works only on yum-based systems'
    end
  end

  describe 'installation result' do
    let(:env) { {LANG: 'C'} }

    let(:docker_image) { 'ansible/centos7-ansible' }

    context 'successful installation' do
      let(:command_stubs) { {curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/true'} }

      it_behaves_like 'should print to stdout',
                      %r{Everything done!\nhttp://8.8.8.8/admin\nlogin: admin\npassword: \w+}
    end

    context 'unsuccessfil installation' do
      let(:command_stubs) { {curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/false'} }

      it_behaves_like 'should exit with error',
                      /There was an error .* send email to support@keitarotds.com/m
    end
  end

  describe 'check running under non-root' do
    let(:env) { {LANG: 'C'} }

    it_behaves_like 'should exit with error', 'You must run this program as root'
  end
end
