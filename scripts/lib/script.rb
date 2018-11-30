require 'open3'
require 'tmpdir'

class Script
  attr_accessor :env, :args, :prompts_with_values, :stored_values, :docker_image, :command_stubs, :commands, :save_files
  attr_reader :stdout, :stderr, :log, :ret_value, :script_command

  DOCKER_DATA_DIR = '/data'
  DOCKER_SCRIPTS_DIR = '/scripts'

  def initialize(
    script_command,
    env: {},
    args: '',
    prompts_with_values: {},
    docker_image: nil,
    command_stubs: {},
    commands: [],
    save_files: []
  )
    @script_command = script_command
    @base_name = File.basename(script_command, '.*')
    @log_file = "#{@base_name}.log"

    @env, @args, @prompts_with_values, @docker_image, @command_stubs, @commands, @save_files =
      env, args, prompts_with_values, docker_image, command_stubs, commands, [*save_files]
  end

  def call(current_dir:)
    invoke_script_cmd(current_dir)
    read_log
  end

  def self.docker_installed?
    system("sh -c 'command -v docker > /dev/null'")
  end

  private

  def invoke_script_cmd(current_dir)
    # puts make_cmd(current_dir).sub(' -i ', ' -it ')
    # byebug
    Open3.popen3(*make_cmd(current_dir)) do |stdin, stdout, stderr, wait_thr|
      stdout.sync = true
      stdin.sync = true

      @stdout = emulate_interactive_io(stdin, stdout)
      @stderr = Thread.new { stderr.read }.value

      @ret_value = wait_thr.value
    end
  end

  def read_log
    @log = without_formatting(IO.read(@log_file)) rescue nil
  end

  def make_cmd(current_dir)
    if docker_image
      docker_run = "docker run #{docker_env} --name keitaro_scripts_test -i --rm"
      docker_run += " -v #{scripts_dir}:#{DOCKER_SCRIPTS_DIR}"
      docker_run += " -v #{current_dir}:#{DOCKER_DATA_DIR}"
      docker_run += " -w #{DOCKER_DATA_DIR}"
      docker_run += " #{docker_image}"
      evaluated_commands = make_command_stubs + commands + [command_with_args("./#{@script_command}", args)]
      %Q{#{docker_run} sh -c '#{evaluated_commands.join(' && ')}'}
    else
      raise "Cann't stub fake commands in real system. Please use docker mode." if command_stubs.any? || commands.any?
      [stringified_env, command_with_args("#{current_dir}/#{@script_command}", args)]
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

  def command_with_args(script_command, args)
    "#{script_command} #{args}".tap do |cmd|
      save_files.each do |filepath|
        cmd << " && cp #{filepath} #{DOCKER_DATA_DIR}"
      end
    end
  end

  def scripts_dir
    File.expand_path("#{__dir__}/..")
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

        if prompts_with_values.any? && prompt =~ / > $/
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
  unless Script.docker_installed?
    puts 'You need to install the docker for running this specs'
  end
end

