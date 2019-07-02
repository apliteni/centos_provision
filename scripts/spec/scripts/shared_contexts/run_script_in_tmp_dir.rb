require 'shell'

RSpec.shared_context 'run script in tmp dir', run_script_in_tmp_dir: :yes do
  before { @current_dir = Dir.mktmpdir('', '/tmp') }
  before { @old_current_dir = Dir.pwd; Dir.chdir(@current_dir) }
  before { FileUtils.copy("#{ROOT_PATH}/#{subject.script_command}", @current_dir) }

  after { Dir.chdir(@old_current_dir) }
  after { FileUtils.rm_rf(@current_dir) }

  def run_script(inventory_values: {installer_version: Script::INSTALLER_RELEASE_VERSION})
    if defined?(copy_files)
      copy_files.each do |path_to_file|
        FileUtils.copy(path_to_file, @current_dir)
      end
    end
    Inventory.write(inventory_values)
    subject.call(current_dir: @current_dir)
    @inventory = Inventory.read_from_log(subject.log)
  end
end
