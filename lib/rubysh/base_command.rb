require 'shellwords'

module Rubysh
  # TODO:
  #
  # - freeze after initialize?
  class BaseCommand
    def stringify_arg(arg)
      case arg
      when BaseCommand, BaseDirective
        arg.stringify
      when Hash
        arg.inspect
      else
        Shellwords.shellescape(arg.to_s)
      end
    end

    def to_s
      "Command: #{stringify}"
    end

    def inspect
      to_s
    end

    def create_runner
      Runner.new(self)
    end

    def run(&blk)
      create_runner.run(&blk)
    end

    def run_async(&blk)
      create_runner.run_async(&blk)
    end

    def check_call(&blk)
      create_runner.check_call(&blk)
    end

    def |(other)
      raise NotImplementedError.new("Override in subclass")
    end

    def initialize(args)
      raise NotImplementedError.new("Override in subclass")
    end

    def start_async(runner)
      raise NotImplementedError.new("Override in subclass")
    end

    def wait(runner)
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
