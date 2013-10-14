require 'set'
require 'thread'

class Rubysh::Subprocess
  # We can't actually rely on an EOF once our subprocess has died,
  # since it may have forked and a child inherited the parent's
  # fds. (This happens, for example, when using SSH's ControlPersist.)
  #
  # E.g. try Rubysh.run('ruby', 'bad.rb', Rubysh.>) with:
  #   # cat bad.rb
  #   fork {sleep 1000}
  class PidAwareParallelIO < ParallelIO
    @pids_mutex = Mutex.new
    @parallel_ios = {}
    @old_sigchld_handler = nil

    def self.register_parallel_io(parallel_io, breaker_writer)
      @pids_mutex.synchronize do
        register_sigchld_handler if @parallel_ios.length == 0
        @parallel_ios[parallel_io] = breaker_writer

        # This is needed in case the SIGCHLD is handled before the
        # writer is stored.
        trigger_breaker(breaker_writer)
      end
    end

    def self.deregister_parallel_io(parallel_io)
      @pids_mutex.synchronize do
        @parallel_ios.delete(parallel_io)
        deregister_sigchld_handler if @parallel_ios.length == 0
      end
    end

    def self.handle_sigchld
      # It's ok for this operation to race against other
      # threads. Break loop on all currently active selectors. This
      # could in theory cause a thundering herd, but it's probably not
      # worth the work to defend against.
      @parallel_ios.values.each {|writer| trigger_breaker(writer)}
    end

    def self.trigger_breaker(writer)
      begin
        writer.write_nonblock('a') unless writer.closed?
      rescue Errno::EAGAIN, Errno::EPIPE
      end
    end

    def self.register_sigchld_handler
      @old_sigchld_handler = Signal.trap('CHLD') {handle_sigchld}
      # MRI returns nil for a DEFAULT handler, but it also treats nil
      # as IGNORE.
      @old_sigchld_handler ||= 'DEFAULT'
    end

    def self.deregister_sigchld_handler
      Signal.trap('CHLD', @old_sigchld_handler)
    end

    attr_reader :finalized

    # readers/writers should be hashes mapping {fd => name}
    def initialize(readers, writers, subprocesses)
      @breaker_reader, @breaker_writer = IO.pipe
      @subprocesses = subprocesses
      @finalized = false

      readers = readers.dup
      readers[@breaker_reader] = nil
      super(readers, writers)

      register_subprocesses
    end

    def register_subprocesses
      self.class.register_parallel_io(self, @breaker_writer)
    end

    def run_once(timeout=nil)
      return if @finalized

      @subprocesses.each do |subprocess|
        subprocess.wait(true)
      end

      # All subprocesses have exited! We're done here.
      if @subprocesses.all?(&:status)
        finalize_all
        return
      end

      super
    end

    def finalize_all
      @breaker_writer.close

      # We're guaranteed that if a process exited, all of its bytes
      # are immediately available to us.
      consume_all_available

      available_readers.each {|reader| reader.close}
      available_writers.each {|writer| writer.close}
      self.class.deregister_parallel_io(self)

      @finalized = true
    end
  end
end
