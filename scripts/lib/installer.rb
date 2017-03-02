require 'open3'
require 'tmpdir'
require 'active_support'

class Installer
  INSTALLER_ROOT = File.expand_path(File.dirname(__FILE__) + '/../')
  INSTALLER_CMD = 'install.sh'
  INVENTORY_FILE = 'hosts.txt'
  LOG_FILE = 'install.log'
  RUNNING_MODE_SCRIPT = :script
  RUNNING_MODE_PIPE = :pipe

  class Inventory
    attr_reader :values

    LINES_DIVIDER = "\n"
    VALUES_DIVIDER = '='
    LOG_PRE_INVENTORY_LINE = 'Write inventory file'
    LOG_POST_INVENTORY_LINE = 'Starting stage 4:'


    def initialize(values: {})
      self.values = values
    end

    def read_from_log(log_content)
      inventory_from_log_match = log_content.match(/#{LOG_PRE_INVENTORY_LINE}(.*)#{LOG_POST_INVENTORY_LINE}/m)
      unless inventory_from_log_match.nil?
        read(inventory_from_log_match[1].gsub(/^ +/, ''))
      end
    end

    def read(content)
      self.values = content
                      .split(LINES_DIVIDER)
                      .grep(/#{VALUES_DIVIDER}/)
                      .map { |line| k, v = line.split(VALUES_DIVIDER); [k, v] }
                      .to_h
    end

    def self.write_to_file(file, values)
      strings = values
                  .map { |key, value| [key, value] }
                  .map { |array| array.join(VALUES_DIVIDER) }
                  .push('')
      IO.write(file, strings.join(LINES_DIVIDER))
    end

    def values=(values)
      @values = values.map { |k, v| [k.to_sym, v] }.to_h
    end
  end

  attr_accessor :env, :args, :prompts_with_values, :stored_values, :docker_image, :command_stubs, :running_mode
  attr_reader :stdout, :stderr, :log, :ret_value, :inventory

  def initialize(
      env: {},
      args: '',
      prompts_with_values: {},
      stored_values: {},
      docker_image: nil,
      command_stubs: {},
      running_mode: RUNNING_MODE_SCRIPT
  )
    @env, @args, @prompts_with_values, @stored_values, @docker_image, @command_stubs, @running_mode =
      env, args, prompts_with_values, stored_values, docker_image, command_stubs, running_mode
    @inventory = Inventory.new
  end

  def call(current_dir: nil)
    if current_dir.nil?
      Dir.mktmpdir('', '/tmp') do |current_dir|
        Dir.chdir(current_dir) do
          run_in_dir(current_dir)
        end
      end
    else
      run_in_dir(current_dir)
    end
  end

  def self.docker_installed?
    system("sh -c 'command -v docker > /dev/null'")
  end

  private

  def run_in_dir(current_dir)
    write_to_inventory(stored_values)
    invoke_installer_cmd(current_dir)
    read_log
    read_inventory
  end

  def write_to_inventory(stored_values)
    Inventory.write_to_file(INVENTORY_FILE, stored_values)
  end

  def invoke_installer_cmd(current_dir)
    FileUtils.copy("#{INSTALLER_ROOT}/#{INSTALLER_CMD}", current_dir)

    Open3.popen3(*installer_cmd(current_dir)) do |stdin, stdout, stderr, wait_thr|
      stdout.sync = true
      stdin.sync = true

      @stdout = emulate_interactive_io(stdin, stdout)
      @stderr = Thread.new { stderr.read }.value

      @ret_value = wait_thr.value
    end
  end

  def read_log
    @log = without_formatting(IO.read(LOG_FILE)) if File.exist?(LOG_FILE)
  end

  def read_inventory
    inventory.read_from_log(log)
  end

  def installer_cmd(current_dir)
    if docker_image
      docker_run = "docker run #{docker_env} --name keitaro_installer_test -i --rm -v #{current_dir}:/data -w /data #{docker_image}"
      commands = make_command_stubs + [command_with_args("./#{INSTALLER_CMD}", args)]
      %Q{#{docker_run} sh -c '#{commands.join(' && ')}'}
    else
      raise "Cann't stub fake commands in real system. Please use docker mode." if command_stubs.any?
      [stringified_env, command_with_args("#{current_dir}/#{INSTALLER_CMD}", args)]
    end
  end

  def docker_env
    env.map { |key, value| "-e #{key}=#{value}" }.join(' ')
  end

  def make_command_stubs
    command_stubs.map do |command, fake_command|
      %Q{rm -f `sh -c "command -v #{command}"` && cp #{fake_command} /bin/#{command}}
    end
  end

  def stringified_env
    env.map { |key, value| [key.to_s, value.to_s] }.to_h
  end

  def command_with_args(command, args)
    case running_mode
    when RUNNING_MODE_SCRIPT
      "#{command} #{args}"
    when RUNNING_MODE_PIPE
      "cat #{command} | bash -s -- #{args}"
    else
      raise "Unknown running mode: #{running_mode}"
    end
  end

  def without_formatting(output)
    output.gsub /\e\[\d+(;\d+)*m/, ''
  end

  def emulate_interactive_io(stdin, stdout)
    out = ''
    reader_thread = Thread.new {
      begin
        stdout_chunk = without_formatting(read_stream(stdout))
        out << stdout_chunk

        break if stdout_chunk == ''

        prompt = stdout_chunk.split("\n").last

        if prompt =~ / > $/
          key = prompt.match(/[^>]+/)[0].gsub(/\[.*\]/, '').strip
          if prompts_with_values.key?(key)
            stdin.puts(prompts_with_values[key])
          else
            stdin.puts('value')
            puts "Value for prompt #{prompt.inspect} not found, using fake value instead"
          end
        end
      end while true
    }
    reader_thread.value
    out
  end

  def read_stream(stdout)
    buffer = ''

    begin
      char = stdout.getc
      return buffer if char.nil?

      buffer << char
    end while buffer !~ / > /

    buffer
  end

end

begin
  unless Installer.docker_installed?
    puts 'You need to install the docker for running this specs'
  end
end

