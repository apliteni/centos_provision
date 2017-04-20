require 'spec_helper'

RSpec.describe 'test-run-command.sh' do
  include_context 'run script in tmp dir'
  include_context 'build subject'

  SUCCESS_EXIT_CODE = 0
  ERROR_EXIT_CODE = 1

  let(:script_name) { 'test-run-command.sh' }
  let(:print_sh_counter) { 30 }
  let(:run_command_args) {}
  let(:helper_scripts_path) { "#{File.dirname(File.expand_path(__FILE__, '../'))}/run_command_tester" }

  let(:args) { "'#{helper_scripts_path}/#{helper_script} #{print_sh_counter} #{print_sh_exit_code}' #{run_command_args}" }

  describe 'test standard failing filter' do
    let(:helper_script) { 'print.sh' }

    shared_examples_for 'prints lines to' do |destination|
      it_behaves_like 'should print to', destination, [
        'output 0',
        'error 0',
        'output 29',
        'error 29',
      ]
    end

    context 'successful command run' do
      let(:print_sh_exit_code) { SUCCESS_EXIT_CODE }

      it_behaves_like 'prints lines to', :log
      it_behaves_like 'prints lines to', :stdout

      context 'hide_output specified' do
        let(:run_command_args) { "'Running command' hide_output" }

        it_behaves_like 'prints lines to', :log
        it_behaves_like 'should print to', :stdout, 'Running command . OK'
      end
    end

    context 'failed command run' do
      let(:print_sh_exit_code) { ERROR_EXIT_CODE }

      it_behaves_like 'prints lines to', :log
      it_behaves_like 'prints lines to', :stdout

      describe 'should print last 20 lines of command stderr/stdout' do
        it_behaves_like 'should print to', :stderr, ['error 10', 'error 29', 'output 10', 'output 29']
        it_behaves_like 'should not print to', :stderr, ['error 0', 'error 9', 'output 0', 'output 9']
      end
    end
  end
end
