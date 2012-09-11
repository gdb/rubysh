module Rubysh
  # TODO: pipes should not win out over redirects. Currently:
  #
  # ls /tmp >/tmp/outfile.txt | cat
  #
  # does the wrong thing.
  class Pipeline < BaseCommand
    attr_accessor :pipeline

    def initialize(pipeline)
      raise Rubysh::Error::BaseError.new("Cannot create an empty pipeline") if pipeline.length == 0
      @pipeline = pipeline
    end

    # sh semantics are that your exitstatus is that of the last in the
    # pipeline
    def status(runner)
      @pipeline[-1].status(runner)
    end

    def prepare!(runner)
      @pipeline.each {|command| command.prepare!(runner)}
    end

    def pipeline_pairs
      @pipeline[0...-1].zip(@pipeline[1..-1])
    end

    def stringify
      @pipeline.map {|cmd| cmd.stringify}.join(' | ')
    end

    def |(other)
      self.class.new(pipeline + [other])
    end

    def start_async(runner)
      last_pipe = nil

      pipeline_pairs.each do |left, right|
        # TODO: maybe create an object to represent the pipe
        # relationship, instead of manually assembling here.
        #
        # Don't want to have more than 2 pipes open at a time, so need
        # to #run_async and #close here.
        pipe = Subprocess::PipeWrapper.new
        setup_pipe(runner, pipe, left, right)

        left.start_async(runner)
        last_pipe.close if last_pipe
        last_pipe = pipe
      end

      @pipeline[-1].start_async(runner)
      last_pipe.close if last_pipe
    end

    def setup_pipe(runner, pipe, left, right)
      left.set_stdout(runner, pipe.writer)
      right.set_stdin(runner, pipe.reader)
    end

    def wait(runner)
      # It's likely we should actually wait for these in parallel; I'm
      # not really sure right now. Might be tricky to avoid waiting
      # for other processes run by this program (could probably use
      # process groups for that?)
      @pipeline.each {|cmd| cmd.wait(runner)}
    end
  end
end
