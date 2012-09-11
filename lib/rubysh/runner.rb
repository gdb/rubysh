module Rubysh
  class Runner
    attr_accessor :command, :targets

    def initialize(command)
      @command = command
      @targets = {}
      @state = {}

      @parallel_io = nil

      prepare!
    end

    def prepare!
      @command.prepare!(self)
    end

    def run_async
      @command.start_async(self)
    end

    def wait
      @command.wait(self)
    end

    def run
      run_async
      run_io
      wait
      self
    end

    def run_io
      prepare_io unless @parallel_io
      @parallel_io.run
    end

    # For internal use
    def state(object)
      @state[object] ||= {}
    end

    def target_state(target_name)
      @targets[target_name] || raise(Rubysh::Error::BaseError.new("Invalid target: #{target_name.inspect} (valid targets are: #{@targets.keys.inspect})"))
    end

    def readers
      readers = {}
      @targets.each do |target_name, target_state|
        next unless target_state[:target_reading?]
        readers[target_name] = target_state[:target]
      end
      readers
    end

    def writers
      writers = {}
      @targets.each do |target_name, target_state|
        next if target_state[:target_reading?]
        writers[target_name] = target_state[:target]
      end
      writers
    end

    private

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
