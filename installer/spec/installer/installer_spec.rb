require 'spec_helper'

require 'open3'

INSTALLER_CMD = 'install.sh'
INSTALLER_PATH = File.expand_path(File.dirname(__FILE__)) + "/../../bin/#{INSTALLER_CMD}"

describe 'invoke installer.sh' do
  let(:options) { [] }

  def invoke_installer_sh
    options_str = options.join(' ')
    Open3.capture3("#{INSTALLER_PATH} #{options_str}")
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

  shared_examples_for 'should exit with error status' do
    specify { expect(get_result(invoke_installer_sh)).not_to be_success }
  end

  context 'with wrong options' do
    let(:options) { %w[-x] }

    it_behaves_like 'should print to stdout', "Usage: #{INSTALLER_CMD}"
    it_behaves_like 'should not print anything to stderr'
    it_behaves_like 'should exit with error status'
  end

  context 'with -v -p options' do
    let(:options) { %w[-v -p] }
    it_behaves_like 'should print to stdout', 'Verbose mode: on'
  end

end
