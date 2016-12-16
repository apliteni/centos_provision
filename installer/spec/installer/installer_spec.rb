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

  shared_examples_for 'should not print anything to stderr' do
    specify { expect(get_stderr(invoke_installer_sh)) }
  end

  context 'with -h flag' do
    let(:options) { %w[-h] }

    it 'should print usage to stdout' do
      stdout = get_stdout(invoke_installer_sh)
      expect(stdout).to match("Usage: #{INSTALLER_CMD}")
    end

    it_behaves_like 'should not print anything to stderr'
  end
end
