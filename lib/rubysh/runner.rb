module Rubysh
  class Runner
    attr_accessor :command, :targets

    def initialize(command)
      @runner_state = :initialized

      @command = command
      @targets = {}
      @state = {}

      @parallel_io = nil

      prepare!
    end

    def data(target_name)
      state = target_state(target_name)
      raise Rubysh::Error::BaseError.new("Can only access data for readable FDs") unless state[:target_reading?]
      state[:buffer].join
    end

    # Ruby's Process::Status. Has fun things like pid and signaled?
    def full_status(command=nil)
      command ||= @command
      @command.status(self)
    end

    def pid(command=nil)
      command ||= @command
      @command.pid(self)
    end

    # Convenience wrapper
    def exitstatus(command=nil)
      if st = full_status(command)
        st.exitstatus
      else
        nil
      end
    end

    # API for running/waiting
    def run_async
      raise Rubysh::Error::AlreadyRunError.new("You have already run this #{self.class} instance. Cannot run again. You can run its command directly though, which will create a fresh #{self.class} instance.") unless @runner_state == :initialized
      @command.start_async(self)
      @runner_state = :started
      self
    end

    def wait
      run_io
      do_wait
    end

    def run
      run_async
      run_io
      do_wait
    end

    def readers
      readers = {}
      @targets.each do |target_name, target_state|
        next unless target_state[:target_reading?]
        target = target_state[:target]
        readers[target] = target_name
      end
      readers
    end

    def writers
      writers = {}
      @targets.each do |target_name, target_state|
        next if target_state[:target_reading?]
        target = target_state[:target]
        writers[target] = target_name
      end
      writers
    end

    def to_s
      inspect
    end

    def inspect
      extras = []
      valid_readers = readers.values.map(&:inspect).join(', ')
      valid_writers = readers.values.map(&:inspect).join(', ')

      extras << "readers: #{valid_readers}" if valid_readers.length > 0
      extras << "writers: #{valid_writers}" if valid_writers.length > 0
      if status = exitstatus
        extras << "exitstatus: #{status}"
      elsif mypid = pid
        extras << "pid: #{pid}"
      end
      extra_display = extras.length > 0 ? " (#{extras.join(', ')})" : nil

      "#{self.class}: #{command.stringify}#{extra_display}"
    end

    # Internal helpers
    def state(object)
      @state[object] ||= {}
    end

    # Internal helpers
    def target_state(target_name)
      @targets[target_name] || raise(Rubysh::Error::BaseError.new("Invalid target: #{target_name.inspect} (valid targets are: #{@targets.keys.inspect})"))
    end

    private

    def do_wait
      raise Rubysh::Error::AlreadyRunError.new("You must run parallel io before waiting. (Perhaps you want to use the 'run' method, which takes care of the plumbing for you?)") unless @runner_state == :parallel_io_ran
      @command.wait(self)
      @runner_state = :waited
      self
    end

    def run_io
      raise Rubysh::Error::AlreadyRunError.new("You must start the subprocesses before running parallel io. (Perhaps you want to use the 'run' method, which takes care of the plumbing for you?)") unless @runner_state == :started
      prepare_io unless @parallel_io
      @parallel_io.run
      @runner_state = :parallel_io_ran
      self
    end

    def prepare!
      @command.prepare!(self)
    end

    # Can't build this in the prepare stage because pipes aren't built
    # there.
    def prepare_io
      @parallel_io = Subprocess::ParallelIO.new(readers, writers)
      @parallel_io.on_read do |target_name, data|
        if data == Subprocess::ParallelIO::EOF
          Rubysh.log.debug("EOF reached on #{target_name.inspect}")
        else
          Rubysh.log.debug("Just read #{data.inspect} on #{target_name.inspect}")
          @targets[target_name][:buffer] << data
        end
      end

      @parallel_io.on_write do |target_name, written, remaining|
        if data == Subprocess::ParallelIO::EOF
          Rubysh.log.debug("EOF reached on #{target_name.inspect}")
        else
          Rubysh.log.debug("Just wrote #{written.inspect} on #{target_name.inspect}")
        end
      end
    end
  end
end
