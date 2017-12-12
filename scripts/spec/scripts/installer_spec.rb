require 'spec_helper'

RSpec.describe 'install.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:stored_values) { {} }
  let(:script_name) { 'install.sh' }

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
        skip_firewall: 'Do you want to skip installing firewall?',
        ssl: "Do you want to install Free SSL certificates from Let's Encrypt?",
        license_ip: 'Please enter server IP',
        license_key: 'Please enter license key',
        db_name: 'Please enter database name',
        db_user: 'Please enter database user name',
        db_password: 'Please enter database user password',
        db_import: 'Do you want to restore the database from sql-dump?',
        db_import_path: 'Please enter the path to the sql dump file',
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
        db_import: 'Хотите восстановить базу данных из sql-дампа?',
        admin_login: 'Укажите имя администратора keitaro',
        admin_password: 'Укажите пароль администратора keitaro',
      }
    }
  end

  let(:user_values) do
    {
      skip_firewall: 'yes',
      ssl: 'no',
      license_ip: '8.8.8.8',
      license_key: 'WWWW-XXXX-YYYY-ZZZZ',
      db_name: 'keitarodb',
      db_user: 'keitarodb_user',
      db_password: 'keitarodb_password',
      db_import: 'no',
      admin_login: 'admin',
      admin_password: 'admin_password',
    }
  end

  before { Inventory.write(stored_values) }

  it_behaves_like 'should try to detect bash pipe mode'

  it_behaves_like 'should print usage when invoked with', args: '-s -x'

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

  it_behaves_like 'should rotate log files', log_file_name: 'install.log'

  shared_examples_for 'inventory contains value' do |field, value|
    it "inventory file contains field #{field.inspect} with value #{value.inspect}" do
      run_script
      expect(@inventory.values[field]).to match(value)
    end
  end

  shared_examples_for 'inventory does not contain field' do |field|
    it "inventory file does not contain field #{field.inspect}" do
      run_script
      expect(@inventory.values).not_to have_key(field)
    end
  end

  describe 'fields' do
    # `-s` option disables yum/ansible checks
    # `-p` option disables invoking install commands

    let(:options) { '-spl en' }

    shared_examples_for 'field without default' do |field, value: 'user-value'|
      context 'field not stored in inventory' do
        it_behaves_like 'should not show default value', field

        it_behaves_like 'should store user value', field, readed_inventory_value: value
      end

      it_behaves_like 'should take value from previously saved inventory', field, value: value
    end

    shared_examples_for 'field with default' do |field, default:|
      context 'field not stored in inventory' do
        it_behaves_like 'should show default value', field, showed_value: default

        it_behaves_like 'should store default value', field, readed_inventory_value: default

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user-value'
      end

      it_behaves_like 'should take value from previously saved inventory', field
    end

    shared_examples_for 'password field' do |field|
      context 'field not stored in inventory' do
        it_behaves_like 'should show default value', field, showed_value: /\w{16}/

        it_behaves_like 'should store default value', field, readed_inventory_value: /\w+{16}/

        it_behaves_like 'should store user value', field, readed_inventory_value: 'user-value'
      end

      it_behaves_like 'should take value from previously saved inventory', field
    end

    shared_examples_for 'should take value from previously saved inventory' do |field, value: 'stored-value'|
      context 'field stored in inventory' do
        let(:stored_values) { {field => value} }

        it_behaves_like 'should show default value', field, showed_value: value

        it_behaves_like 'should store default value', field, readed_inventory_value: value

        it_behaves_like 'should store user value', field, readed_inventory_value: value
      end
    end

    shared_examples_for 'should store default value' do |field, readed_inventory_value:|
      let(:prompts_with_values) { make_prompts_with_values(:en).merge(prompts[:en][field] => nil) }

      it_behaves_like 'inventory contains value', field, readed_inventory_value
    end

    shared_examples_for 'should store user value' do |field, readed_inventory_value:|
      let(:prompts_with_values) { make_prompts_with_values(:en).merge(prompts[:en][field] => readed_inventory_value) }

      it_behaves_like 'inventory contains value', field, readed_inventory_value
    end

    it_behaves_like 'field without default', :license_ip, value: '1.2.3.4'

    it_behaves_like 'field without default', :license_key, value: 'AAAA-BBBB-CCCC-DDDD'

    it_behaves_like 'field with default', :db_name, default: 'keitaro'

    it_behaves_like 'field with default', :db_user, default: 'keitaro'

    it_behaves_like 'password field', :db_password

    it_behaves_like 'should show default value', :db_import, showed_value: 'no'

    it_behaves_like 'should store default value', :db_import, readed_inventory_value: 'no'

    it_behaves_like 'field with default', :admin_login, default: 'admin'

    it_behaves_like 'password field', :admin_password

    it_behaves_like 'inventory contains value', :evaluated_by_installer, 'yes'

    describe 'correctly stores yes/no fields' do
      it_behaves_like 'should print to', :log, /Write inventory file.*ssl=no/m
    end
  end

  describe 'inventory file' do
    describe 'kversion field' do
      context '-k option missed' do
        let(:options) { '-s -p' }
        before { run_script }
        it { expect(@inventory.values).not_to have_key(:kversion) }
      end

      context '-k specified' do
        let(:options) { '-s -p -k 7' }
        before { run_script }
        it { expect(@inventory.values[:kversion]).to eq('7') }
      end

      context 'specified -k with wrong value' do
        let(:options) { '-s -p -k 9' }
        it_behaves_like 'should exit with error', 'Specified Keitaro Release "9" is not supported'
      end
    end
  end

  context 'without actual installing software' do
    let(:options) { '-p' }
    let(:docker_image) { 'centos' }

    before(:all) { `docker rm keitaro_installer_test &>/dev/null` }

    shared_examples_for 'should install keitarotds' do
      it_behaves_like 'should print to', :stdout,
                      'curl -sSL https://github.com/keitarocorp/centos_provision/archive/master.tar.gz | tar xz'

      it_behaves_like 'should print to', :stdout,
                      "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-master/playbook.yml"

      context '-t specified' do
        let(:options) { '-p -t tag1,tag2' }

        it_behaves_like 'should print to', :stdout,
                        "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-master/playbook.yml --tags tag1,tag2"
      end

      context '-i specified' do
        let(:options) { '-p -i tag1,tag2' }

        it_behaves_like 'should print to', :stdout,
                        "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-master/playbook.yml --skip-tags tag1,tag2"
      end
    end

    context 'yum presented' do
      describe 'should upgrade system' do
        let(:command_stubs) { {yum: '/bin/true'} }

        it_behaves_like 'should print to', :stdout, 'yum update -y'
      end
    end

    context 'yum presented, ansible presented' do
      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true'} }

      it_behaves_like 'should print to', :log, "Try to found yum\nFOUND"
      it_behaves_like 'should print to', :log, "Try to found ansible\nFOUND"
      it_behaves_like 'should not print to', :stdout, 'yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum presented, ansible not presented' do
      let(:command_stubs) { {yum: '/bin/true'} }

      it_behaves_like 'should print to', :log, "Try to found yum\nFOUND"
      it_behaves_like 'should print to', :log, "Try to found ansible\nNOT FOUND"
      it_behaves_like 'should print to', :stdout, 'yum install -y epel-release'
      it_behaves_like 'should print to', :stdout, 'yum install -y ansible'

      it_behaves_like 'should install keitarotds'
    end

    context 'yum not presented' do
      let(:commands) { ['rm /usr/bin/yum'] }
      it_behaves_like 'should print to', :log, "Try to found yum\nNOT FOUND"
      it_behaves_like 'should exit with error', 'This installer works only on yum-based systems'
    end
  end

  describe 'installation result' do
    let(:docker_image) { 'centos' }

    context 'successful installation' do
      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/true'} }

      it_behaves_like 'should print to', :stdout,
                      %r{Everything is done!\nhttp://8.8.8.8/admin\nlogin: admin\npassword: \w+}
    end

    context 'unsuccessful installation' do
      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', curl: '/bin/true', tar: '/bin/true', 'ansible-playbook': '/bin/false'} }

      it_behaves_like 'should exit with error', [
        /There was an error evaluating current command\n(.*\n){3}  ANSIBLE_FORCE_COLOR=true ansible-playbook/,
        'Installation log saved to install.log',
        'Configuration settings saved to hosts.txt',
        'You can rerun `install.sh`'
      ]
    end
  end

  describe 'nat support checking' do
    context 'nat is unsupported' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', iptables: '/bin/false'} }

      it_behaves_like 'should print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory contains value', :skip_firewall, 'yes'

      context 'user cancels installation' do
        let(:user_values) do
          {
            skip_firewall: 'no',
          }
        end

        it_behaves_like 'should exit with error', 'Please run this program in system with firewall support'
      end
    end

    context 'nat is supported' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', iptables: '/bin/true'} }

      it_behaves_like 'should not print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory does not contain field', :skip_firewall
    end
  end

end
