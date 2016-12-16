require 'spec_helper'

require 'open3'

INSTALLER_CMD = 'install.sh'
INSTALLER_PATH = File.expand_path(File.dirname(__FILE__)) + "/../../bin/#{INSTALLER_CMD}"

describe 'invoke installer.sh' do
  let(:options) { [] }
  let(:env) { {} }

  def invoke_installer_sh
    options_str = options.join(' ')
    env_vars = env.map { |k, v| [k.to_s, v] }.to_h
    Open3.capture3(env_vars, "#{INSTALLER_PATH} #{options_str}")
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

  context 'with wrong options' do
    let(:options) { %w[-x] }

    it_behaves_like 'should exit with error'
    it_behaves_like 'should print to stderr', "Usage: #{INSTALLER_CMD}"
  end

  context 'with `-v` `-p` options' do
    let(:options) { %w[-v -p] }

    it_behaves_like 'should exit without errors'
    it_behaves_like 'should not print anything to stderr'
    it_behaves_like 'should print to stdout', 'Verbose mode: on'
  end

  context 'with `-l` option' do
    let(:env) { {LANG: 'C'} }
    let(:options) { %W[-v -l #{lang}] }

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

  describe 'detects language from LANG environment variable' do
    let(:options) { %w[-v] } # Switch on verbose mode

    context 'LANG=ru_RU.UTF-8' do
      let(:env) { {LANG: 'ru_RU.UTF-8'} }

      it_behaves_like 'should exit without errors'
      it_behaves_like 'should not print anything to stderr'
      it_behaves_like 'should print to stdout', 'Language: ru'
    end
  end

end
