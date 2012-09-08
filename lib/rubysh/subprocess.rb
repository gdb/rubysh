# Adapted from https://github.com/ahoward/open4
require 'fcntl'
require 'timeout'
require 'thread'

# Using YAML to avoid the JSON dep. open4 uses Marshal to pass around
# the exception object, but I'm always a bit sketched by Marshal when
# it's not needed (i.e. don't want the subprocess to have the ability
# to execute code in the parent, even if it should lose that ability
# post-exec.)
require 'yaml'

require 'rubysh/subprocess/pipe_wrapper'

module Rubysh
  class Subprocess
    attr_accessor :command, :args
    attr_accessor :pid, :status, :exec_error

    def initialize(args)
      raise ArgumentError.new("Must provide an array") unless args.kind_of?(Array)
      raise ArgumentError.new("No command specified") unless args.length > 0
      @command = args[0]
      @args = args[1..-1]

      @exec_status = PipeWrapper.new
      @exec_status.cloexec

      @pid = nil
      @status = nil
      @exec_error = nil
    end

    def run
      do_run unless @pid
      @pid
    end

    def wait(nonblock=false)
      do_wait(nonblock) unless @status
      @status
    end

    private

    def do_run
      @pid = fork do
        @exec_status.write_only
        do_exec
      end
      @exec_status.read_only
    end

    def do_wait(nonblock=false)
      flags = nonblock ? Process::WNOHANG : nil
      return nil unless result = Process.waitpid2(@pid, flags)

      pid, @status = result
      Rubysh.assert(pid == @pid,
        "Process.waitpid2 returned #{pid} while waiting for #{@pid}",
        true)
      handle_exec_error
    end

    def do_exec
      begin
        Kernel.exec([command, command], *args)
        raise Rubysh::Error::BaseError.new("This code should be unreachable. If you are seeing this exception, it means someone overrode Kernel.exec. That's not very nice of them.")
      rescue Exception => e
        msg = {
          'message' => e.message,
          'klass' => e.class.to_s,
          # TODO: this may need coercion in Ruby1.9
          'caller' => e.send(:caller)
        }
        @exec_status.dump_yaml_and_close(msg)
        # Note: atexit handlers will fire in this case. May want to do
        # something about that.
        raise
      end
    end

    def handle_exec_error
      msg = @exec_status.load_yaml_and_close

      case msg
      when false
        # success!
      when Hash
        @exec_error = Rubysh::Error::ExecError.new("Failed to exec in subprocess: #{msg['message']}", msg['klass'], msg['caller'])
      else
        @exec_error = Rubysh::Error::BaseError.new("Invalid message received over the exec_status pipe: #{msg.inspect}")
      end
    end
  end
end
