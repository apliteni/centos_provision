require 'spec_helper'

RSpec.describe 'install.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  BRANCH='releases/stable'
  PROVISION_DIRECTORY="centos_provision"
  PLAYBOOK_PATH="#{PROVISION_DIRECTORY}/playbook.yml"
  INVENTORY_PATH='.keitaro/etc/keitaro/config/inventory'

  let(:inventory_values) { {installer_version: Script::INSTALLER_RELEASE_VERSION} }
  let(:script_name) { 'install.sh' }

  let(:skip_firewall) { 'yes' }
  let(:license_ip) { '8.8.8.8' }
  let(:license_key) { 'WWWW-XXXX-YYYY-ZZZZ' }
  let(:db_restore_path) { nil }
  let(:db_restore_salt) { nil }
  let(:default_command_stubs) do
    {
      'ansible-playbook': '/bin/true',
      ansible: '/bin/true',
      curl: '/bin/true',
      iptables: '/bin/true',
      tar: '/bin/true',
      yum: '/bin/true',
    }
  end

  let(:prompts) do
    {
      en: {
        skip_firewall: 'Do you want to skip installing firewall?',
        license_key: 'Please enter license key',
        db_restore_path: 'Please enter the path to the SQL dump file if you want to restore database',
        db_restore_salt: 'Please enter the value of the "salt" parameter from the old config (application/config/config.ini.php)',
      },
      ru: {
        license_key: 'Укажите лицензионный ключ',
      }
    }
  end

  let(:user_values) do
    {
      skip_firewall: skip_firewall,
      license_key: license_key,
      db_restore_path: db_restore_path,
      db_restore_salt: db_restore_salt,
    }
  end

  it_behaves_like 'should try to detect bash pipe mode'

  it_behaves_like 'should print usage when invoked with', args: '-s -x'

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

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


  def stub_detecting_license_edition_type_answer(ip, license_type)
    [
      %Q{echo "echo echo #{ip}" > /bin/hostname},
      'chmod a+x /bin/hostname',
      %Q{echo "if [[ \\"\\$2\\" =~ edition_type ]]; then echo #{license_type}; else /bin/true; fi" > /bin/curl},
      'chmod a+x /bin/curl'
    ]
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
        let(:inventory_values) { {field => value} }

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
      let(:commands) { stub_detecting_license_edition_type_answer('1.1.1.1', 'trial') }

      it_behaves_like 'inventory contains value', :license_ip, '1.1.1.1'
    end

    it_behaves_like 'field without default', :license_key, value: 'AAAA-BBBB-CCCC-DDDD'

    it_behaves_like 'inventory contains value', :evaluated_by_installer, 'yes'
  end

  describe 'inventory file' do
    describe 'kversion field' do
      context '-k option missed' do
        let(:options) { '-s -p' }
        before { run_script }
        it { expect(@inventory.values).not_to have_key(:kversion) }
      end

      context '-k specified' do
        let(:options) { '-s -p -k 9' }
        before { run_script }
        it { expect(@inventory.values[:kversion]).to eq('9') }
      end

      context 'specified -k with wrong value' do
        context 'specified v10' do
          let(:options) { '-s -p -k 10' }
          it_behaves_like 'should exit with error', "Specified Keitaro release '10' is not supported"
        end

        context 'specified v8' do
          let(:options) { '-s -p -k 8' }
          # it_behaves_like 'should exit with error', "Specified Keitaro release '8' is not supported"
        end
      end
    end
  end

  context 'when running in upgrade mode' do
    let(:options) { '-s -p -r -t upgrade' }

    shared_examples_for "upgrades from versions" do |versions|

      expected_tags = %w[upgrade] + versions.map { |version| "upgrade-from-#{version}" }

      it "invokes ansiple-playbook with upgrade tags #{expected_tags}" do
        run_script
        all_tags_string = subject.stdout.match(/`.* ansible-playbook .* --tags (?<tags>.*)`/)[:tags]
        upgrade_tags = all_tags_string.split(',').select{ |tag| tag.start_with?('upgrade') }
        expect(upgrade_tags).to eq(expected_tags)
      end

      #it_behaves_like 'should print to', :stdout, /--tags #{tags.join(',')}(`|,(?!upgrade))/
    end

    context 'when too old version is installed' do
      let(:inventory_values) { {} }
      it_behaves_like "upgrades from versions", %w[1.5 2.0 2.12 2.13 2.16]
    end

    context 'when 1.9 version installed' do
      let(:inventory_values) { {installer_version: '1.9'} }
      it_behaves_like "upgrades from versions", %w[2.0 2.12 2.13 2.16]
    end

    context 'when 2.1 version installed' do
      let(:inventory_values) { {installer_version: '2.16'} }
      it_behaves_like "upgrades from versions", %w[2.16]
    end
  end

  context '-t specified' do
    let(:options) { '-s -p -t tag1,tag2' }

    it_behaves_like 'should print to', :stdout,
                    "ansible-playbook -vvv -i #{INVENTORY_PATH} #{PLAYBOOK_PATH} --tags tag1,tag2"
  end

  context '-i specified' do
    let(:options) { '-s -p -i tag1,tag2' }

    it_behaves_like 'should print to', :stdout,
                    "ansible-playbook -vvv -i #{INVENTORY_PATH} #{PLAYBOOK_PATH} --skip-tags tag1,tag2"
  end

  context 'without actual installing software' do
    let(:options) { '-p' }
    let(:docker_image) { 'centos' }
    let(:commands) { stub_detecting_license_edition_type_answer('1.1.1.1', 'trial') }

    before(:all) { `docker rm keitaro_installer_test &>/dev/null` }

    shared_examples_for 'should install keitaro' do
      it_behaves_like 'should print to', :stdout,
                      %r{mkdir -p #{PROVISION_DIRECTORY} && curl -fsSL https://files.keitaro.io/scripts/#{BRANCH}/playbook.tar.gz | tar -xzC #{PROVISION_DIRECTORY}}

      it_behaves_like 'should print to', :stdout,
                      "ansible-playbook -vvv -i #{INVENTORY_PATH} #{PLAYBOOK_PATH}"

    end

    context 'yum presented' do
      describe 'should upgrade system' do
        let(:command_stubs) { default_command_stubs }

        it_behaves_like 'should print to', :stdout, 'yum update -y'
      end
    end

    context 'yum presented, ansible presented' do
      let(:command_stubs) { default_command_stubs }

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
    let(:commands) { stub_detecting_license_edition_type_answer('8.8.8.8', 'trial') }

    let(:docker_image) { 'centos' }

    context 'successful installation' do
      let(:command_stubs) { default_command_stubs }

      it_behaves_like 'should print to', :stdout,
                      %r{Everything is done!\nhttp://8.8.8.8/admin\nlogin: admin\npassword: \w+}
    end

    context 'unsuccessful installation' do
      let(:command_stubs) { default_command_stubs.merge('ansible-playbook': '/bin/false') }

      it_behaves_like 'should exit with error', [
        %r{There was an error evaluating current command\n(.*\n){3}.* ansible-playbook},
        'Installation log saved to .keitaro/var/log/keitaro/install.log',
        'Configuration settings saved to .keitaro/etc/keitaro/config/inventory',
        'You can rerun `curl -fsSL https://keitaro.io/install.sh > run; bash run`'
      ]
    end
  end

  describe 'nat support checking' do
    let(:docker_image) { 'centos' }

    let(:commands) { stub_detecting_license_edition_type_answer('1.2.3.4', 'trial') }

    context 'nat is not supported' do
      let(:command_stubs) { default_command_stubs.merge(iptables: '/bin/false') }

      it_behaves_like 'should print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory contains value', :skip_firewall, 'yes'

      context 'user cancels installation' do
        let(:skip_firewall) { 'no' }

        it_behaves_like 'should exit with error', 'Please run this program in system with firewall support'
      end
    end

    context 'nat is supported' do
      let(:command_stubs) { default_command_stubs }

      it_behaves_like 'should not print to', :stdout,
                      'It looks that your system does not support firewall'

      it_behaves_like 'inventory contains value', :skip_firewall, 'no'
    end
  end

  describe 'dump checking' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { default_command_stubs }
    let(:commands) do
      [%Q{echo "echo #{mime_type}" > /bin/file}, 'chmod a+x /bin/file'] +
        stub_detecting_license_edition_type_answer('1.2.3.4', 'commercial')
    end

    let(:db_restore_salt) { 'some.salt' }

    context 'valid plain text dump' do
      let(:mime_type) { 'text/plain' }
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/valid.sql"] }
      let(:db_restore_path) { 'valid.sql' }

      it_behaves_like 'should print to', :stderr, 'Checking SQL dump . OK'
      it_behaves_like 'should print to', :log,
                      /head -n \d+ 'valid.sql'/,
                      /tail -n \d+ 'valid.sql'/
      it_behaves_like 'should print to', :log,
                      "TABLES_PREFIX='keitaro_' ansible-playbook "
    end

    context 'valid gzipped dump' do
      let(:mime_type) { 'application/x-gzip' }
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/valid.sql.gz"] }
      let(:db_restore_path) { 'valid.sql.gz' }

      it_behaves_like 'should print to', :stderr, 'Checking SQL dump . OK'
      it_behaves_like 'should print to', :log,
                      /zcat 'valid.sql.gz' | head -n \d+/,
                      /zcat 'valid.sql.gz' | tail -n \d+/
      it_behaves_like 'should print to', :log,
                      "TABLES_PREFIX='keitaro_' ansible-playbook "
    end

    context 'dump is invalid' do
      let(:mime_type) { 'text/plain' }
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/invalid.sql"] }
      let(:db_restore_path) { ['invalid.sql', ''] }

      it_behaves_like 'should print to', :stderr, 'Checking SQL dump . NOK'
    end

    context 'dump is invalid' do
      let(:mime_type) { 'application/x-gzip' }
      let(:copy_files) { ["#{ROOT_PATH}/spec/files/invalid.sql.gz"] }
      let(:db_restore_path) { ['invalid.sql.gz', ''] }

      it_behaves_like 'should print to', :stderr, 'Checking SQL dump . NOK'
    end
  end

  describe 'fails if keitaro is already installed' do

    INVENTORY_DIR = File.dirname(INVENTORY_PATH)

    let(:docker_image) { 'centos' }

    let(:command_stubs) { default_command_stubs }
    let(:commands) { ["mkdir -p #{INVENTORY_DIR}", %Q{echo "installed=true" > #{INVENTORY_PATH}}] }

    it_behaves_like 'should exit with error', 'Keitaro is already installed'
  end
end
