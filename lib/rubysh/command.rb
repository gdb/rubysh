module Rubysh
  class Command < BaseCommand
    attr_accessor :args, :extra_opts, :subprocess

    def initialize(args)
      @args = args
      @subprocess = nil

      # From things like pipe, where context dictates some properties
      # of how this command is run.
      @extra_opts = []
    end

    def add_opt(opt)
      @extra_opts << opt
    end

    def stringify
      @args.map do |arg|
        stringify_arg(arg)
      end.join(' ')
    end

    def run_async
      instantiate_subprocess unless @subprocess
      @subprocess.run
    end

    def wait
      @subprocess.wait
    end

    def stdout=(value)
      opt = FD.new(:stdout) > value
      add_opt(opt)
    end

    def stdin=(value)
      opt = FD.new(:stdin) < value
      add_opt(opt)
    end

    def status
      subprocess.status
    end

    def instantiate_subprocess
      opts = []
      args = @args.map do |arg|
        case arg
        when BaseCommand
          raise NotImplementedError.new('Not ready for subshells yet')
        when Redirect
          opts << arg
          nil
        else
          arg
        end
      end.compact
      opts += @extra_opts
      @subprocess = Subprocess.new(args, opts)
    end
  end
end
