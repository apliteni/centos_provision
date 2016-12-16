require 'spec_helper'

require 'open3'
require 'tmpdir'

INSTALLER_CMD = 'install.sh'
INSTALLER_PATH = File.expand_path(File.dirname(__FILE__)) + "/../../bin/#{INSTALLER_CMD}"

describe 'installer.sh' do
  around(:example) do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        example.run
      end
    end
  end

  let(:args) { '' }
  let(:env) { {} }

  let(:license_ip) { '8.8.8.8' }
  let(:stdin_data) do
    <<-END
#{license_ip}
    END
  end

  def invoke_installer_sh
    env_vars = env.map { |k, v| [k.to_s, v] }.to_h
    Open3.capture3(env_vars, "#{INSTALLER_PATH} #{args}", stdin_data: stdin_data)
  end

  def get_stdout(invoke_installer_sh_result)
    invoke_installer_sh_result[0]
  end

  def get_stderr(invoke_installer_sh_result)
    invoke_installer_sh_result[1]
  end

  def get_result(invoke_installer_sh_result)
    invoke_installer_sh_result[2]
  end

  shared_examples_for 'should not print anything to stderr' do
    specify { expect(get_stderr(invoke_installer_sh)).to be_empty }
  end

  shared_examples_for 'should print to stdout' do |expected_text|
    specify { expect(get_stdout(invoke_installer_sh)).to match(expected_text) }
  end

  shared_examples_for 'should print to stderr' do |expected_text|
    specify { expect(get_stderr(invoke_installer_sh)).to match(expected_text) }
  end

  shared_examples_for 'should exit with error' do
    specify { expect(get_result(invoke_installer_sh)).not_to be_success }
  end

  shared_examples_for 'should exit without errors' do
    specify { expect(get_result(invoke_installer_sh)).to be_success }
  end

  describe 'invoked' do
    context 'with wrong args' do
      let(:args) { '-x' }

      it_behaves_like 'should exit with error'
      it_behaves_like 'should print to stderr', "Usage: #{INSTALLER_CMD}"
    end

    context 'with `-v` `-p` args' do
      let(:args) { '-v -p' }

      it_behaves_like 'should exit without errors'
      it_behaves_like 'should not print anything to stderr'
      it_behaves_like 'should print to stdout', 'Verbose mode: on'
    end

    context 'with `-l` option' do
      let(:env) { {LANG: 'C'} }
      let(:args) { "-v -l #{lang}" }

      context 'with `en` value' do
        let(:lang) { 'en' }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: en'
      end

      context 'with `ru` value' do
        let(:lang) { 'ru' }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'with unsupported value' do
        let(:lang) { 'xx' }

        it_behaves_like 'should exit with error'
        it_behaves_like 'should print to stderr', 'Specified language "xx" is not supported'
      end
    end

    # TODO: Detect from LC_MESSAGES
    describe 'detects language from LANG environment variable' do
      let(:args) { '-v' } # Switch on verbose mode for testing purposes

      context 'LANG=ru_RU.UTF-8' do
        let(:env) { {LANG: 'ru_RU.UTF-8'} }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'LANG=ru_UA.UTF-8' do
        let(:env) { {LANG: 'ru_UA.UTF-8'} }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: ru'
      end

      context 'LANG=en_US.UTF-8' do
        let(:env) { {LANG: 'en_US.UTF-8'} }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: en'
      end

      context 'LANG=de_DE.UTF-8' do
        let(:env) { {LANG: 'de_DE.UTF-8'} }

        it_behaves_like 'should exit without errors'
        it_behaves_like 'should not print anything to stderr'
        it_behaves_like 'should print to stdout', 'Language: en'
      end
    end
  end

  describe 'generated hosts file' do
    let(:hosts_file_content) { File.read('.keitarotds-hosts') }

    it 'creates hosts file based on entered info' do
      invoke_installer_sh
      expect(File.exist?('.keitarotds-hosts')).to be_truthy
    end

    it 'contains license_ip key' do
      invoke_installer_sh
      expect(hosts_file_content).to match("\nlicense_ip = #{license_ip}")
    end
  end
end
