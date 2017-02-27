require 'spec_helper'

RSpec.describe 'installer.sh' do
  let(:args) { '' }
  let(:env) { {LANG: 'C'} }
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

  shared_examples_for 'should print to log' do |expected_text|
    it "prints to stdout #{expected_text.inspect}" do
      installer.call(current_dir: @current_dir)
      expect(installer.log).to match(expected_text)
    end
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

  shared_examples_for 'should exit with error' do |expected_texts|
    it "exits with error #{expected_texts}" do
      installer.call
      expect(installer.ret_value).not_to be_success
      [*expected_texts].each do |expected_text|
        expect(installer.stderr).to match(expected_text)
      end
    end
  end

  describe 'checking bash pipe mode' do
    let(:args) { '-s -p' }

    it_behaves_like 'should print to log', "Can't detect pipe bash mode. Stdin hack disabled"
  end

  describe 'invoked' do
    context 'with wrong args' do
      let(:args) { '-x' }

      it_behaves_like 'should exit with error', "Usage: #{Installer::INSTALLER_CMD}"
    end

    context 'with `-l` option' do
      let(:args) { "-l #{lang}" }

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
    # `-s` option disables yum/ansible checks
    # `-p` option disables invoking install commands

    let(:args) { '-spl en' }

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

  describe 'inventory file' do
    describe 'kversion field' do
      context '-k option missed' do
        let(:args) { '-s -p' }
        before { installer.call }
        it { expect(installer.inventory.values).not_to have_key(:kversion) }
      end

      context '-k specified' do
        let(:args) { '-s -p -k 7' }
        before { installer.call }
        it { expect(installer.inventory.values[:kversion]).to eq('7') }
      end

      context 'specified -k with wrong value' do
        let(:args) { '-s -p -k 9' }
        it_behaves_like 'should exit with error', 'Specified Keitaro TDS Release "9" is not supported'
      end
    end
  end

  context 'without actual installing software' do
    let(:args) { '-p' }

    before(:all) { `docker rm keitaro_installer_test &>/dev/null` }

    shared_examples_for 'should install keitarotds' do
      it_behaves_like 'should print to stdout',
                      'curl -sSL https://github.com/keitarocorp/centos_provision/archive/master.tar.gz | tar xz'

      it_behaves_like 'should print to stdout',
                      "ansible-playbook -vvv -i #{Installer::INVENTORY_FILE} centos_provision-master/playbook.yml"

      context '-t specified' do
        let(:args) { '-p -t tag1,tag2' }

        it_behaves_like 'should print to stdout',
                        "ansible-playbook -vvv -i #{Installer::INVENTORY_FILE} centos_provision-master/playbook.yml --tags tag1,tag2"
      end
    end

    context 'yum presented, ansible presented' do
      let(:docker_image) { 'ansible/centos7-ansible' }

      it_behaves_like 'should print to log', "Try to found yum\nOK"
      it_behaves_like 'should print to log', "Try to found ansible\nOK"
      it_behaves_like 'should not print to stdout', 'Execute command: yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum presented, ansible not presented' do
      let(:docker_image) { 'centos' }

      it_behaves_like 'should print to log', "Try to found yum\nOK"
      it_behaves_like 'should print to log', "Try to found ansible\nNOK"
      it_behaves_like 'should print to stdout', 'yum install -y epel-release'
      it_behaves_like 'should print to stdout', 'yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum not presented' do
      let(:docker_image) { 'ubuntu' }

      it_behaves_like 'should print to log', "Try to found yum\nNOK"
      it_behaves_like 'should exit with error', 'This installer works only on yum-based systems'
    end
  end

  describe 'installation result' do
    let(:docker_image) { 'ansible/centos7-ansible' }

    context 'successful installation' do
      let(:command_stubs) { {curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/true'} }

      it_behaves_like 'should print to stdout',
                      %r{Everything done!\nhttp://8.8.8.8/admin\nlogin: admin\npassword: \w+}
    end

    context 'unsuccessfil installation' do
      let(:command_stubs) { {curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/false'} }

      it_behaves_like 'should exit with error', [
        'There was an error evaluating command `ansible-playbook',
        'Installation log saved to install.log',
        'Configuration settings saved to hosts.txt',
        'You can rerun `install.sh`'
      ]
    end
  end

  describe 'check running under non-root' do
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
        installer.call(current_dir: @current_dir)
        expect(File).to be_exists(filename)
      end
    end

    shared_examples_for 'should move old install.log to' do |newname|
      specify do
        old_content = IO.read('install.log')
        installer.call(current_dir: @current_dir)
        expect(IO.read(newname)).to eq(old_content)
      end
    end

    context 'log files does not exists' do
      it_behaves_like 'should create', 'install.log'
    end

    context 'install.log exists' do
      before { IO.write('install.log', 'some log') }

      it_behaves_like 'should create', 'install.log'

      it_behaves_like 'should move old install.log to', 'install.log.1'
    end

    context 'install.log, install.log.1 exists' do
      before { IO.write('install.log', 'some log') }
      before { IO.write('install.log.1', 'some log.1') }

      it_behaves_like 'should create', 'install.log'

      it_behaves_like 'should move old install.log to', 'install.log.2'
    end
  end
end
