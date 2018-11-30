require 'spec_helper'

RSpec.describe 'install.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:stored_values) { {} }
  let(:script_name) { 'install.sh' }

  let(:ssl) { 'no' }
  let(:ssl_domains) { nil }
  let(:ssl_email) { nil }
  let(:skip_firewall) { 'yes' }
  let(:license_ip) { '8.8.8.8' }
  let(:license_key) { 'WWWW-XXXX-YYYY-ZZZZ' }
  let(:db_restore) { 'no' }
  let(:db_restore_path) { nil }
  let(:db_restore_path_want_exit) { nil }
  let(:db_restore_salt) { nil }
  let(:admin_login) { 'admin' }
  let(:admin_password) { 'admin_password' }

  let(:prompts) do
    {
      en: {
        skip_firewall: 'Do you want to skip installing firewall?',
        ssl: 'Do you want to install Free SSL certificates (you can do it later)?',
        ssl_domains: 'Please enter server domains, separated by comma without spaces (i.e. domain1.tld,domain2.tld)',
        ssl_email: 'Please enter your email (you can left this field empty)',
        license_ip: 'Please enter server IP',
        license_key: 'Please enter license key',
        db_restore: 'Do you want to restore the database from SQL dump?',
        db_restore_path: 'Please enter the path to the SQL dump file',
        db_restore_salt: 'Please enter the value of "salt" parameter from the old config (application/config/config.ini.php)',
        db_restore_path_want_exit: 'Do you want to exit?',
        admin_login: 'Please enter Keitaro admin login',
        admin_password: 'Please enter Keitaro admin password'
      },
      ru: {
        ssl: 'Установить бесплатные SSL сертификаты (можно сделать это позже)?',
        license_ip: 'Укажите IP адрес сервера',
        license_key: 'Укажите лицензионный ключ',
        db_restore: 'Хотите восстановить базу данных из SQL дампа?',
        admin_login: 'Укажите имя администратора Keitaro',
        admin_password: 'Укажите пароль администратора Keitaro',
      }
    }
  end

  let(:user_values) do
    {
      skip_firewall: skip_firewall,
      ssl: ssl,
      ssl_domains: ssl_domains,
      ssl_email: ssl_email,
      license_ip: license_ip,
      license_key: license_key,
      db_restore: db_restore,
      db_restore_path: db_restore_path,
      db_restore_path_want_exit: db_restore_path_want_exit,
      db_restore_salt: db_restore_salt,
      admin_login: admin_login,
      admin_password: admin_password,
    }
  end

  it_behaves_like 'should try to detect bash pipe mode'

  it_behaves_like 'should print usage when invoked with', args: '-s -x'

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

  shared_examples_for 'inventory contains value' do |field, value|
    it "inventory file contains field #{field.inspect} with value #{value.inspect}" do
      run_script(inventory_values: stored_values)
      expect(@inventory.values[field]).to match(value)
    end
  end

  shared_examples_for 'inventory does not contain field' do |field|
    it "inventory file does not contain field #{field.inspect}" do
      run_script(inventory_values: stored_values)
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

    shared_examples_for 'field with default' do |field, default:, user_value: 'user-value'|
      context 'field not stored in inventory' do
        it_behaves_like 'should show default value', field, showed_value: default

        it_behaves_like 'should store default value', field, readed_inventory_value: default

        it_behaves_like 'should store user value', field, readed_inventory_value: user_value
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

    context 'should detect ip' do
      let(:options) { '-p' }
      let(:docker_image) { 'centos' }
      let(:commands) { [
        'echo "echo 127.0.0.1; echo 1.1.1.1" > /bin/hostname',
        'chmod a+x /bin/hostname'
      ] }

      it_behaves_like 'should show default value', :license_ip, showed_value: '1.1.1.1'

      it_behaves_like 'should store default value', :license_ip, readed_inventory_value: '1.1.1.1'

      it_behaves_like 'should store user value', :license_ip, readed_inventory_value: '1.1.1.1'

      it_behaves_like 'should take value from previously saved inventory', :license_ip, value: '1.1.1.1'
    end

    it_behaves_like 'field without default', :license_key, value: 'AAAA-BBBB-CCCC-DDDD'

    it_behaves_like 'should show default value', :db_restore, showed_value: 'no'

    it_behaves_like 'should store default value', :db_restore, readed_inventory_value: 'no'

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
        before { run_script(inventory_values: stored_values) }
        it { expect(@inventory.values).not_to have_key(:kversion) }
      end

      context '-k specified' do
        let(:options) { '-s -p -k 9' }
        before { run_script(inventory_values: stored_values) }
        it { expect(@inventory.values[:kversion]).to eq('9') }
      end

      context 'specified -k with wrong value' do
        let(:options) { '-s -p -k 10' }
        it_behaves_like 'should exit with error', 'Specified Keitaro Release "10" is not supported'
      end
    end

    describe 'cpu_cores' do
    end
  end

  context 'without actual installing software' do
    let(:options) { '-p' }
    let(:docker_image) { 'centos' }

    before(:all) { `docker rm keitaro_installer_test &>/dev/null` }

    shared_examples_for 'should install keitaro' do
      it_behaves_like 'should print to', :stdout,
                      'curl -sSL https://github.com/apliteni/centos_provision/archive/release-0.9.tar.gz | tar xz'

      it_behaves_like 'should print to', :stdout,
                      "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-release-0.9/playbook.yml"

      context '-t specified' do
        let(:options) { '-p -t tag1,tag2' }

        it_behaves_like 'should print to', :stdout,
                        "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-release-0.9/playbook.yml --tags tag1,tag2"
      end

      context '-i specified' do
        let(:options) { '-p -i tag1,tag2' }

        it_behaves_like 'should print to', :stdout,
                        "ansible-playbook -vvv -i #{Inventory::INVENTORY_FILE} centos_provision-release-0.9/playbook.yml --skip-tags tag1,tag2"
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

      it_behaves_like 'should install keitaro'
    end

    context 'yum presented, ansible not presented' do
      let(:command_stubs) { {yum: '/bin/true', curl: '/bin/false'} }

      it_behaves_like 'should print to', :log, "Try to found yum\nFOUND"
      it_behaves_like 'should print to', :log, "Try to found ansible\nNOT FOUND"
      it_behaves_like 'should print to', :stdout, 'yum install -y epel-release'
      it_behaves_like 'should print to', :stdout, 'yum install -y ansible'

      it_behaves_like 'should install keitaro'
    end

    context 'yum not presented' do
      let(:commands) { ['rm /usr/bin/yum'] }
      it_behaves_like 'should print to', :log, "Try to found yum\nNOT FOUND"
      it_behaves_like 'should exit with error', 'This installer works only on CentOS'
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
        %r{There was an error evaluating current command\n(.*\n){3}.* ansible-playbook},
        'Installation log saved to install.log',
        'Configuration settings saved to .keitaro/installer_config',
        'You can rerun `install.sh`'
      ]
    end
  end

  describe 'nat support checking' do

    let(:docker_image) { 'centos' }

    context 'nat is unsupported' do
      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', iptables: '/bin/false', curl: '/bin/false'} }

      it_behaves_like 'should print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory contains value', :skip_firewall, 'yes'

      context 'user cancels installation' do
        let(:skip_firewall) { 'no' }

        it_behaves_like 'should exit with error', 'Please run this program in system with firewall support'
      end
    end

    context 'nat is supported' do
      let(:command_stubs) { {yum: '/bin/true', ansible: '/bin/true', iptables: '/bin/true', curl: '/bin/false'} }

      it_behaves_like 'should not print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory contains value', :skip_firewall, 'no'
    end
  end

  describe 'dump checking' do
    let(:docker_image) { 'centos' }
    # we must not skip checks with -sp options, but we don't want to run yum upgrade in docker
    let(:command_stubs) { {yum: '/bin/false'} }

    let(:db_restore) { 'yes' }
    let(:db_restore_salt) { 'some.salt' }
    let(:db_restore_path_want_exit) { 'yes' }

    context 'valid plain text dump' do
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/valid.sql"] }
      let(:db_restore_path) { 'valid.sql' }

      it_behaves_like 'should print to', :stdout, 'Checking SQL dump . OK'
      it_behaves_like 'should print to', :log, / grep .* valid.sql/
    end

    context 'valid gzipped dump' do
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/valid.sql.gz"] }
      let(:db_restore_path) { 'valid.sql.gz' }

      it_behaves_like 'should print to', :stdout, 'Checking SQL dump . OK'
      it_behaves_like 'should print to', :log, / zgrep .* valid.sql.gz/
    end

    context 'dump is invalid' do
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/invalid.sql"] }
      let(:db_restore_path) { 'invalid.sql' }

      it_behaves_like 'should print to', :stdout, 'Checking SQL dump . NOK'
      it_behaves_like 'should exit with error', 'SQL dump is broken'
    end
  end

  describe 'fails if keitaro is already installed' do
    let(:docker_image) { 'centos' }
    let(:commands) { ['mkdir -p /var/www/keitaro/var', 'touch /var/www/keitaro/var/install.lock'] }

    it_behaves_like 'should exit with error', 'Keitaro is already installed'
  end

  describe 'ssl enabled' do
    let(:options) { '-spl en' }

    let(:ssl) { 'yes' }
    let(:ssl_domains) { 'd1.com,d2.com' }
    let(:ssl_email) { 'some@mail.com' }

    it_behaves_like 'should print to', :stdout, 'Enabling SSL . SKIPPED'
    it_behaves_like 'should print to', :log,
                    %r{curl .*/enable-ssl.sh | bash -s -- -k -a -e some@mail.com d1.com d2.com}
  end
end
