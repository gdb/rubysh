module Rubysh
  # TODO: pipes should not win out over redirects. Currently:
  #
  # ls /tmp >/tmp/outfile.txt | cat
  #
  # does the wrong thing.
  class Pipeline < BaseCommand
    attr_accessor :pipeline

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def instantiate_subprocess
      @pipeline.each {|cmd| cmd.instantiate_subprocess}
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

    def run_async
      return unless @pipeline.length > 0

      last_pipe = nil

      pipeline_pairs.each do |left, right|
        # TODO: maybe create an object to represent the pipe
        # relationship, instead of manually assembling here.
        #
        # Don't want to have more than 2 pipes open at a time, so need
        # to #run_async and #close here.
        pipe = Subprocess::PipeWrapper.new
        setup_pipe(pipe, left, right)

        left.run_async
        last_pipe.close if last_pipe
        last_pipe = pipe
      end

      @pipeline[-1].run_async
      last_pipe.close if last_pipe
    end

    def setup_pipe(pipe, left, right)
      left.stdout = pipe.writer
      left.post_fork {pipe.write_only}

      right.stdin = pipe.reader
      right.post_fork {pipe.read_only}
    end

    def wait
      # It's likely we should actually wait for these in parallel; I'm
      # not really sure right now. Might be tricky to avoid waiting
      # for other processes run by this program (could probably use
      # process groups for that?)
      @pipeline.each {|cmd| cmd.wait}
    end
  end
end
