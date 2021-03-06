# Adapted from https://github.com/ahoward/open4
require 'fcntl'
require 'timeout'
require 'thread'

require 'rubysh/subprocess/parallel_io'
require 'rubysh/subprocess/pid_aware_parallel_io'
require 'rubysh/subprocess/pipe_wrapper'

module Rubysh
  class Subprocess
    attr_accessor :command, :args, :directives, :runner
    attr_accessor :pid, :status, :exec_error

    # TODO: switch directives over to an OrderedHash of some form? Really
    # want to preserve the semantics here.
    def initialize(args, blk=nil, directives=[], post_fork=[], runner=nil)
      raise ArgumentError.new("Must provide an array (#{args.inspect} provided)") unless args.kind_of?(Array)

      if args.length > 0 && blk
        raise ArgumentError.new("Provided both arguments (#{args.inspect}) and a block (#{blk.inspect}). You can only provide one.")
      elsif args.length == 0 && !blk
        raise ArgumentError.new("No command specified (#{args.inspect} provided)")
      end

      @command = args[0]
      @args = args[1..-1]
      @blk = blk
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
      "Subprocess: command=#{@command.inspect} blk=#{@blk.inspect} args=#{@args.inspect} directives: #{@directives.inspect}"
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
      begin
        result = Process.waitpid2(@pid, flags)
      rescue Errno::ECHILD => e
        raise Rubysh::Error::ECHILDError.new("No unreaped process #{@pid}. This could indicate a bug in Rubysh, but more likely means you have something in your codebase which is wait(2)ing on subprocesses.")
      end

      return unless result

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

      if @blk
        run_blk
      else
        exec_program
      end
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

    def run_blk
      # Close the writing end of the pipe
      @exec_status.read_only

      begin
        # Run the actual block
        @blk.call
      rescue Exception => e
        render_exception(e)
        hard_exit(e)
      else
        hard_exit(nil)
      end
    end

    def exec_program
      begin
        Kernel.exec([command, command], *args)
      rescue Exception => e
        msg = {
          'message' => e.message,
          'klass' => e.class.to_s,
          # TODO: this may need coercion in Ruby1.9
          'caller' => e.send(:caller)
        }
        @exec_status.dump_json_and_close(msg)
        # Abort without running at_exit handlers or giving the user a
        # chance to accidentally catch the exit.
        hard_exit(e)
      else
        raise Rubysh::Error::UnreachableError.new("This code should be unreachable. If you are seeing this exception, it means someone overrode Kernel.exec. That's not very nice of them.")
      end
    end

    def handle_exec_error
      msg = @exec_status.load_json_and_close

      case msg
      when false
        # success!
      when Hash
        @exec_error = Rubysh::Error::ExecError.new("Failed to exec in subprocess: #{msg['message']}", msg['message'], msg['klass'], msg['caller'])
      else
        @exec_error = Rubysh::Error::BaseError.new("Invalid message received over the exec_status pipe: #{msg.inspect}")
      end

      raise @exec_error if @exec_error
    end

    def render_exception(e)
      $stderr.print("[Rubysh subprocess #{$$}] #{e.class}: #{e.message}\n\t")
      $stderr.print(e.backtrace.join("\n\t"))
      $stderr.print("\n")
    end

    # Broken out for the tests
    def hard_exit(exception)
      status = exception ? 1 : 0
      exit!(status)
    end
  end
end
