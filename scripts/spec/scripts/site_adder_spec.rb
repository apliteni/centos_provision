require 'spec_helper'

RSpec.describe 'add-site.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  let(:inventory_values) { {installer_version: Script::INSTALLER_RELEASE_VERSION} }
  let(:script_name) { 'add-site.sh' }
  let(:all_command_stubs) { {nginx: '/bin/true'} }
  let(:nginx_conf) {
    <<-END
      server_name _;
      root /var/www/keitaro;
    END
  }

  let(:make_proper_nginx_conf) do
    [
      'mkdir -p /etc/nginx/conf.d/keitaro /etc/nginx/conf.d/local/keitaro',
      %Q{echo -e "#{nginx_conf}"> /etc/nginx/conf.d/keitaro.conf},
    ]
  end

  let(:make_site_root_dir) { ['mkdir -p /var/www/example.com'] }

  let(:prompts) do
    {
      en: {
        site_domains: 'Please enter domains separated by comma without spaces',
        site_root: 'Please enter site root directory',
      },
      ru: {
        site_domains: 'Укажите список доменов через запятую без пробелов',
        site_root: 'Укажите корневую директорию сайта',
      }
    }
  end

  let(:user_values) do
    {
      site_domains: 'example.com',
      site_root: '/var/www/example.com',
    }
  end

  it_behaves_like 'should try to detect bash pipe mode'

  it_behaves_like 'should print usage when invoked with', args: '-s -x'

  it_behaves_like 'should detect language'

  it_behaves_like 'should support russian prompts'

  it_behaves_like 'should not run under non-root'

  context 'without actual running commands' do
    include_context 'run in docker'
    let(:options) { '-p' }

    context 'keitaro is installed, nginx is configured properly' do
      let(:command_stubs) { all_command_stubs }

      let(:commands) { make_proper_nginx_conf + make_site_root_dir }

      it_behaves_like 'should print to', :log, [
        "Checking /var/www/example.com directory existence\nYES",
      ]
    end

    context 'site is not installed' do
      let(:command_stubs) { all_command_stubs }

      let(:commands) { make_proper_nginx_conf }

      it_behaves_like 'should print to', :log, "Checking /var/www/example.com directory existence\nNO"

      it_behaves_like 'should exit with error', '/var/www/example.com directory does not exist'
    end
  end

  describe 'creating vhost' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + make_site_root_dir }
    let(:save_files) { '/etc/nginx/conf.d/example.com.conf' }

    it 'should create example.com.conf' do
      run_script
      expect(File.exist?("#{@current_dir}/example.com.conf")).to be_truthy
    end

    it 'vhost file should be properly configured' do
      run_script
      content = File.read("#{@current_dir}/example.com.conf")
      expect(content).to match('server_name example.com;')
    end

    context 'alias specified' do
      let(:save_files) { ['/etc/nginx/conf.d/example.com.conf', '/etc/nginx/conf.d/www.example.com.conf'] }

      let(:user_values) do
        {
          site_domains: 'example.com,www.example.com',
          site_root: '/var/www/example.com',
        }
      end

      it 'vhost file should be properly configured' do
        run_script
        content = File.read("#{@current_dir}/example.com.conf")
        expect(content).to match('server_name example.com;')
      end

      it 'vhost file should be properly configured' do
        run_script
        content = File.read("#{@current_dir}/www.example.com.conf")
        expect(content).to match('server_name www.example.com;')
        expect(content).to match('root /var/www/example.com;')
      end
    end
  end

  describe 'should run obsolete add-site for old versions' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:remove_inventory) { ['rm -rf .keitaro'] }
    let(:commands) { make_proper_nginx_conf + make_site_root_dir + remove_inventory }

    it_behaves_like 'should print to', :stderr, 'You should upgrade the server configuration'
  end

  describe 'add-site result' do
    include_context 'run in docker'

    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf + make_site_root_dir }

    it_behaves_like 'should print to', :stdout, /Everything is done!/
  end

  describe 'reloading nginx' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to', :log, /nginx -s reload/
  end
end
