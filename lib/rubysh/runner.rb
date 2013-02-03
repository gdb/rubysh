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

    def write(bytes, target=0)
      raise Rubysh::Error::AlreadyRunError.new("Can only write to a runner in runner_state :started, not #{@runner_state.inspect}") unless @runner_state == :started
      state = target_state(target, false)
      target_name = state[:target_name]
      @parallel_io.write(target_name, bytes, false)
    end

    # A bit of an unothordox read interface, not sure if I like
    # it. Also, the target/opts magic is probably too magical (and not
    # consistent with write!)
    #
    # You can do:
    #
    # read: finish the subprocess, and read from FD 1 in the child
    # read(:how => :partial): wait until there are bytes on FD 1, and
    #   then return what you can
    # read(2, :how => :partial): Do the same for FD 2
    # read(:stdout, :how => :partial): Do the same with whatever the named
    #   descriptor :stdout
    # read(:how => :nonblock): Return whatever is immediately available
    def read(target=nil, opts=nil)
      raise Rubysh::Error::AlreadyRunError.new("Can only read from a runner in runner_state :started or :waited, not #{@runner_state.inspect}") unless @runner_state == :started || @runner_state == :waited

      if target.kind_of?(Hash)
        opts = target
        target = nil
      end
      target ||= 1
      opts ||= {}

      # TODO: add a stringio
      state = target_state(target, true)
      target_name = state[:target_name]

      # Be nice to people and validate the hash
      valid_keys = [:how]
      extra_keys = opts.keys - valid_keys
      raise raise Rubysh::Error::BaseError.new("Unrecognized keys #{extra_keys.inspect}. (Valid keys: #{valid_keys.inspect}") if extra_keys.length > 0

      case how = opts[:how]
      when :partial
        # Read until we get some bytes
        @parallel_io.run_once until state[:buffer].length != state[:read_pos]
      when :nonblock
        @parallel_io.read_available(state[:target])
      when nil
        communicate if @runner_state == :started
      else
        raise Rubysh::Error::BaseError.new("Invalid read directive #{how.inspect}")
      end

      state[:buffer].pos = state[:read_pos]
      bytes = state[:buffer].read
      # Could also increment by bytes, but meh.
      state[:read_pos] = state[:buffer].pos
      bytes
    end

    def communicate
      raise Rubysh::Error::AlreadyRunError.new("Can only communicate with a runner in runner_state :started, not #{@runner_state.inspect}") unless @runner_state == :started
      writers.each do |io, target_name|
        @parallel_io.close(target_name) unless io.closed?
      end
      wait
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

    def exec_error
      subprocess = state(@command)[:subprocess]
      subprocess.exec_error
    end

    # API for running/waiting
    def run_async
      raise Rubysh::Error::AlreadyRunError.new("You have already run this #{self.class} instance. Cannot run again. You can run its command directly though, which will create a fresh #{self.class} instance.") unless @runner_state == :initialized
      prepare_io
      @command.start_async(self)
      @runner_state = :started
      self
    end

    def run(input={}, &blk)
      run_async
      blk.call(self) if blk
      run_io
      do_wait
      self
    end

    def check_call(&blk)
      run
      status = full_status
      unless status.success?
        raise Rubysh::Error::BadExitError.new("#{@command} exited with #{rendered_status(status)}")
      end
      status
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
      valid_writers = writers.values.map(&:inspect).join(', ')

      extras << "readers: #{valid_readers}" if valid_readers.length > 0
      extras << "writers: #{valid_writers}" if valid_writers.length > 0
      if status = full_status
        extras << rendered_status(status)
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
    def target_state(target_name, reading=nil)
      case target_name
      when Symbol
        target_state = @targets[target_name]
        raise Rubysh::Error::BaseError.new("Invalid target symbol: #{target_name.inspect} (valid target symbols are: #{@targets.keys.inspect})") unless target_state
      when Fixnum
        targets = targets_by_fd_numbers
        target_state = targets[target_name]
        raise Rubysh::Error::BaseError.new("Invalid target fd number: #{target_name.inspect} (valid target fd numbers are: #{targets.keys.inspect}})") unless target_state
      else
        raise Rubysh::Error::BaseError.new("Invalid type for target name: #{target_name.inspect} (#{target_name.class}). Valid types are Symbol and Fixnum.")
      end

      if reading.nil?
        # No checking
      elsif target_state[:target_reading?] && !reading
        raise Rubysh::Error::BaseError.new("Trying to write to read pipe #{target_name}")
      elsif !target_state[:target_reading?] && reading
        raise Rubysh::Error::BaseError.new("Trying to read from write pipe #{target_name}")
      end

      target_state
    end

    private

    def wait
      run_io
      do_wait
    end

    def targets_by_fd_numbers
      @targets.inject({}) do |hash, (_, target_state)|
        fd_num = target_state[:subprocess_fd_number]
        hash[fd_num] = target_state
        hash
      end
    end

    def do_wait
      return unless @runner_state == :parallel_io_ran
      @command.wait(self)
      @runner_state = :waited
      self
    end

    def run_io
      return unless @runner_state == :started
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
        state = @targets[target_name]
        buffer = state[:buffer]
        if data == Subprocess::ParallelIO::EOF
          Rubysh.log.debug("EOF reached on #{target_name.inspect}")
          buffer.close_write
        else
          Rubysh.log.debug("Just read #{data.inspect} on #{target_name.inspect}")
          # Seek to end
          buffer.pos = buffer.length
          buffer.write(data)
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

    def rendered_status(status)
      if exitstatus = status.exitstatus
        "exitstatus: #{exitstatus}"
      elsif termsig = status.termsig
        name, _ = Signal.list.detect {|name, number| number == termsig}
        "termsig: #{name} [signal number #{termsig}]"
      else
        ''
      end
    end
  end
end
