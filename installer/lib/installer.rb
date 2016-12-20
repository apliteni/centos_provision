require 'pathname'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile", Pathname.new(__FILE__).realpath)

require 'rubygems'
require 'bundler/setup'

class Installer
  INSTALLER_CMD = 'install.sh'
  INSTALLER_PATH = File.expand_path(File.dirname(__FILE__)) + "/../bin/#{INSTALLER_CMD}"

  attr_reader :env, :args, :prompts_with_values, :stdout, :stderr, :ret_value

  def initialize(env: {}, args: '', prompts_with_values: {})
    @env, @args, @prompts_with_values = env, args, prompts_with_values
  end

  def call
    Open3.popen3(stringified_env, "#{INSTALLER_PATH} #{args}") do |stdin, stdout, stderr, wait_thr|
      stdout.sync = true
      stdin.sync = true

      @stdout = emulate_interactive_io(stdin, stdout)
      @stderr = Thread.new { stderr.read }.value
      @ret_value =  wait_thr.value
    end
  end

  private

  def stringified_env
    env.map { |k, v| [k.to_s, v.to_s] }.to_h
  end

  def emulate_interactive_io(stdin, stdout)
    out = ''
    reader_thread = Thread.new {
      begin
        stdout_chunk = read_stream(stdout)
        break if stdout_chunk.nil?

        out << stdout_chunk
        prompt = stdout_chunk.split("\n").last
        stdin.puts(prompts_with_values[prompt])
      end while true
    }
    reader_thread.join
    out
  end

  def read_stream(stdout)
    buffer = ''

    begin
      char = stdout.getc
      return if char.nil?

      buffer << char
    end while char != '>'

    buffer << stdout.getc
    buffer
  end

end
