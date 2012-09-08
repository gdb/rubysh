module Rubysh
  class Command < BaseCommand
    attr_accessor :args, :extra_directives, :subprocess

    def initialize(args)
      @args = args
      @subprocess = nil

      # From things like pipe, where context dictates some properties
      # of how this command is run.
      @extra_directives = []
      @extra_post_fork = []
    end

    def add_directive(directive)
      @extra_directives << directive
    end

    def stringify
      @args.map do |arg|
        stringify_arg(arg)
      end.join(' ')
    end

    def run_async
      instantiate_subprocess
      @subprocess.run
    end

    def wait
      @subprocess.wait
    end

    def |(other)
      Pipeline.new([self, other])
    end

    def post_fork(&blk)
      @extra_post_fork << blk
    end

    def stdout=(value)
      directive = FD.new(:stdout) > value
      add_directive(directive)
    end

    def stdin=(value)
      directive = FD.new(:stdin) < value
      add_directive(directive)
    end

    def status
      subprocess.status
    end

    # This whole instantiation thing is kind of janky.
    def instantiate_subprocess
      return @subprocess if @subprocess
      directives = []
      args = @args.map do |arg|
        case arg
        when BaseCommand
          raise NotImplementedError.new('Not ready for subshells yet')
        when Redirect
          directives << arg
          nil
        else
          arg
        end
      end.compact
      directives += @extra_directives
      post_forks = @extra_post_fork
      @subprocess = Subprocess.new(args, directives, post_forks)
    end
  end
end
