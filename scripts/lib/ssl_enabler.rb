require 'open3'
require 'tmpdir'
require 'active_support'

class SslEnabler
  SSL_ENABLER_ROOT = File.expand_path(File.dirname(__FILE__) + '/../')
  SSL_ENABLER_CMD = 'enable-ssl.sh'
  LOG_FILE = 'enable-ssl.log'
  DOCKER_WORKING_DIR = '/data'

  attr_accessor :env, :args, :prompts_with_values, :docker_image, :command_stubs, :commands
  attr_reader :stdout, :stderr, :log, :ret_value

  def initialize(env: {}, args: '', prompts_with_values: {}, docker_image: nil, command_stubs: {}, commands: [])
    @env, @args, @prompts_with_values, @docker_image, @command_stubs, @commands =
      env, args, prompts_with_values, docker_image, command_stubs, commands
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
    invoke_ssl_enabler_cmd(current_dir)
    read_log
  end

  def invoke_ssl_enabler_cmd(current_dir)
    FileUtils.copy("#{SSL_ENABLER_ROOT}/#{SSL_ENABLER_CMD}", current_dir)

    Open3.popen3(*ssl_enabler_cmd(current_dir)) do |stdin, stdout, stderr, wait_thr|
      stdout.sync = true
      stdin.sync = true

      @stdout = emulate_interactive_io(stdin, stdout)
      @stderr = Thread.new { stderr.read }.value

      @ret_value = wait_thr.value
    end
  end

  def read_log
    if File.exist?(LOG_FILE)
      @log = without_formatting(IO.read(LOG_FILE))
    else
      raise "There was an error running '#{SSL_ENABLER_CMD}': '#{@stderr}'"
    end
  end

  def ssl_enabler_cmd(current_dir)
    if docker_image
      docker_run = "docker run #{docker_env} --name keitaro_ssl_enabler_test -i --rm -v #{current_dir}:#{DOCKER_WORKING_DIR} -w #{DOCKER_WORKING_DIR} #{docker_image}"
      runtime_commands = make_command_stubs + commands + ["./#{SSL_ENABLER_CMD} #{args}"]
      %Q{#{docker_run} sh -c '#{runtime_commands.join(' && ')}'}
    else
      raise "Cann't stub fake commands in real system. Please use docker mode." if command_stubs.any? || commands.any?
      [stringified_env, "#{current_dir}/#{SSL_ENABLER_CMD} #{args}"]
    end
  end

  def make_command_stubs
    command_stubs.map do |command, fake_command|
      %Q{rm -f `sh -c "command -v #{command}"` && cp #{fake_command} /bin/#{command}}
    end
  end

  def docker_env
    env.map { |key, value| "-e #{key}=#{value}" }.join(' ')
  end

  def stringified_env
    env.map { |key, value| [key.to_s, value.to_s] }.to_h
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
  unless SslEnabler.docker_installed?
    puts 'You need to install the docker for running this specs'
  end
end

