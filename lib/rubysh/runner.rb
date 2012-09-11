module Rubysh
  class Runner
    def initialize(command)
      @command = command
      @targets = {}
      @state = {}

      prepare!
    end

    def prepare!
      @command.prepare!(self)
    end

    def state(object)
      @state[object] ||= {}
    end

    def run_async
      @command.start_async(self)
    end

    def wait
      @command.wait(self)
    end

    def run
      run_async
      wait
      self
    end
  end
end
