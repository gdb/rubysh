module Rubysh
  class Command < BaseCommand
    attr_accessor :raw_args, :directives, :args

    def initialize(args)
      if args.length == 1 && args[0].kind_of?(Array)
        raise "It looks like you created a Rubysh::Command with a singleton nested array: #{args.inspect}. That'll never be runnable, and probably indicates you forgot a splat somewhere."
      end

      @raw_args = args
      @directives = []
      @args = nil
      @opts = {}

      process_args
    end

    def process_args
      @args = @raw_args.map do |arg|
        case arg
        when BaseCommand
          raise NotImplementedError.new('Not ready for subshells yet')
        when BaseDirective
          @directives << arg
          nil
        when Hash
          @opts.merge!(arg)
          nil
        else
          arg.to_s
        end
      end.compact
    end

    def stringify
      @raw_args.map do |arg|
        stringify_arg(arg)
      end.join(' ')
    end

    def |(other)
      Pipeline.new([self, other])
    end

    def post_fork(runner, &blk)
      extra_post_forks(runner) << blk
    end

    def set_stdout(runner, value)
      directive = FD.new(:stdout) > value
      add_directive(runner, directive)
    end

    def set_stdin(runner, value)
      directive = FD.new(:stdin) < value
      add_directive(runner, directive)
    end

    def status(runner)
      (subprocess = state(runner)[:subprocess]) ? subprocess.status : nil
    end

    def pid(runner)
      (subprocess = state(runner)[:subprocess]) ? subprocess.pid : nil
    end

    def prepare!(runner)
      @directives.each {|directive| directive.prepare!(runner)}
    end

    def start_async(runner)
      # Need to call this *after* we've set up pipeline
      # PipeWrappers. Would prefer to call it in prepare!, but then
      # we'd have to take care of closing the FDs in the parent
      # process here anyway.
      prepare_subprocess(runner)
      state(runner)[:subprocess].run
    end

    def wait(runner)
      state(runner)[:subprocess].wait
    end

    private

    def add_directive(runner, directive)
      extra_directives(runner) << directive
    end

    def state(runner)
      runner.state(self)
    end

    def extra_directives(runner)
      state(runner)[:extra_directives] ||= []
    end

    def base_post_forks
      post_forks = []

      if cwd = @opts[:cwd]
        post_forks << Proc.new {Dir.chdir(cwd)}
      end

      if env = @opts[:env]
        post_forks << Proc.new do
          ENV.clear
          ENV.update(env)
        end
      end

      post_forks
    end

    def extra_post_forks(runner)
      state(runner)[:extra_post_forks] ||= []
    end

    def prepare_subprocess(runner)
      # extras first because they are currently only used for
      # pipeline, which should not win out over internal redirects.
      directives = extra_directives(runner) + @directives
      post_forks = base_post_forks + extra_post_forks(runner)
      state(runner)[:subprocess] = Subprocess.new(args, directives, post_forks, runner)
    end
  end
end
