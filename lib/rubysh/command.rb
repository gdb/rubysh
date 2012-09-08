module Rubysh
  class Command < BaseCommand
    attr_accessor :subprocess

    def initialize(args)
      @args = args
      instantiate_subprocess
    end

    def stringify
      @args.map do |arg|
        stringify_arg(arg)
      end.join(' ')
    end

    def run_async
      @subprocess.run
    end

    def wait
      @subprocess.wait
    end

    def stdout=(value)
      opt = FD.new(:stdout) > value
      @subprocess.add_opt(opt)
    end

    def stdin=(value)
      opt = FD.new(:stdin) < value
      @subprocess.add_opt(opt)
    end

    def status
      subprocess.status
    end

    def instantiate_subprocess
      opts = []
      @args.map do |arg|
        case arg
        when BaseCommand
          raise NotImplementedError.new('Not ready for subshells yet')
        when FD
          opts << arg.to_opt
        end
      end
      @subprocess = Subprocess.new(@args)
    end
  end
end
