module Rubysh
  # TODO:
  #
  # - freeze after initialize?
  # - ensure run is only called once (maybe provide a clone to run
  #   again? or switch to factory?)
  class BaseCommand
    def stringify_arg(arg)
      case arg
      when BaseCommand, BaseDirective
        arg.stringify
      else
        arg.to_s
      end
    end

    def to_s
      "Command: #{stringify}"
    end

    def inspect
      to_s
    end

    def run
      run_async
      wait
    end

    def |(other)
      raise NotImplementedError.new("Override in subclass")
    end

    def initialize(args)
      raise NotImplementedError.new("Override in subclass")
    end

    def run_async
      raise NotImplementedError.new("Override in subclass")
    end

    def wait
      raise NotImplementedError.new("Override in subclass")
    end

    def stringify
      raise NotImplementedError.new("Override in subclass")
    end

    def stdout=(value)
      raise NotImplementedError.new("Override in subclass")
    end

    def stdin=(value)
      raise NotImplementedError.new("Override in subclass")
    end
  end
end
