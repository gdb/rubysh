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

require 'rubysh/subprocess/parallel_io'
require 'rubysh/subprocess/pipe_wrapper'

module Rubysh
  class Subprocess
    attr_accessor :command, :args, :directives, :runner
    attr_accessor :pid, :status, :exec_error

    # TODO: switch directives over to an OrderedHash of some form? Really
    # want to preserve the semantics here.
    def initialize(args, directives=[], post_fork=[], runner=nil)
      raise ArgumentError.new("Must provide an array (#{args.inspect} provided)") unless args.kind_of?(Array)
      raise ArgumentError.new("No command specified (#{args.inspect} provided)") unless args.length > 0
      @command = args[0]
      @args = args[1..-1]
      @directives = directives
      @runner = runner

      Rubysh.assert(@directives.length == 0 || @runner, "Directives provided but no runner is", true)

      @exec_status = nil
      @post_fork = post_fork

      @pid = nil
      @status = nil
      @exec_error = nil

      Rubysh.log.debug("Just created: #{self}")
    end

    def to_s
      "Subprocess: command=#{@command.inspect} args=#{@args.inspect} directives: #{@directives.inspect}"
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
      # Create this here so as to not leave an open pipe hanging
      # around for too long. Not sure what would happen if a child
      # inherited it.
      open_exec_status
      @pid = fork do
        do_run_child
      end
      do_run_parent
    end

    def open_exec_status
      @exec_status = PipeWrapper.new
    end

    def do_run_parent
      # nil in tests
      @exec_status.read_only
      apply_directives_parent
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
      # nil in tests
      @exec_status.write_only
      run_post_fork
      apply_directives_child
      exec_program
    end

    def run_post_fork
      @post_fork.each {|blk| blk.call}
    end

    def apply_directives_parent
      apply_directives(true)
    end

    def apply_directives_child
      apply_directives(false)
    end

    def apply_directives(is_parent)
      @directives.each {|directive| apply_directive(directive, is_parent)}
    end

    def apply_directive(directive, is_parent)
      if is_parent
        directive.apply_parent!(runner)
      else
        directive.apply!(runner)
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
