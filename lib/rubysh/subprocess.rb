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
    attr_accessor :command, :args, :opts
    attr_accessor :pid, :status, :exec_error

    # TODO: switch opts over to an OrderedHash of some form? Really
    # want to preserve the semantics here.
    def initialize(args, opts=[])
      raise ArgumentError.new("Must provide an array (#{args.inspect} provided)") unless args.kind_of?(Array)
      raise ArgumentError.new("No command specified (#{args.inspect} provided)") unless args.length > 0
      @command = args[0]
      @args = args[1..-1]
      @opts = opts

      @exec_status = PipeWrapper.new

      @pid = nil
      @status = nil
      @exec_error = nil

      # Needed for Ruby 1.8, where we can't set IO objects to not
      # close the underlying FD on destruction
      @references = []
    end

    def hold(io)
      @references << io
    end

    def add_opt(opt)
      @opts << opt
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
        do_run_child
      end
      do_run_parent
    end

    def do_run_parent
      @exec_status.read_only
      handle_exec_error
    end

    def do_wait(nonblock=false)
      flags = nonblock ? Process::WNOHANG : nil
      return nil unless result = Process.waitpid2(@pid, flags)

      pid, @status = result
      Rubysh.assert(pid == @pid,
        "Process.waitpid2 returned #{pid} while waiting for #{@pid}",
        true)
    end

    def do_run_child
      @exec_status.write_only
      apply_opts
      exec_program
    end

    def apply_opts
      @opts.each do |key, value|
        case key
        when :redirect
          redirect_fd(*value)
        else
          raise Rubysh::Error::BaseError.new("Invalid opt: #{key.inspect}")
        end
      end
    end

    def redirect_fd(fileno, target)
      # Coerce to FD number
      fileno = fileno.fileno if fileno.respond_to?(:fileno)

      # Really just want dup2. The concurrency story here is a bit
      # off. But should be fine for now.
      begin
        io = IO.for_fd(fileno)
        hold(io)
        io.reopen(target)
      rescue Errno::EBADF
        result = target.fcntl(Fcntl::F_DUPFD, num)
        Rubysh.assert(result == num, "Tried to open #{num} but ended up with #{result} instead")
      end
    end

    def exec_program
      begin
        Kernel.exec([command, command], *args)
        raise Rubysh::Error::UnreachableError.new("This code should be unreachable. If you are seeing this exception, it means someone overrode Kernel.exec. That's not very nice of them.")
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
