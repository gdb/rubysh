module Rubysh
  class Pipe < BaseCommand
    attr_accessor :left, :right

    def initialize(left, right)
      @left = left
      @right = right

      @pipe = Subprocess::PipeWrapper.new
      setup_pipe
    end

    def setup_pipe
      @left.stdout = @pipe.writer
      @right.stdin = @pipe.reader
    end

    def close_pipe
      @pipe.close
    end

    def stringify
      "#{left.stringify} | #{right.stringify}"
    end

    def run_async
      @left.run_async
      @right.run_async
      close_pipe
    end

    def wait
      # It's likely we should actually wait for these in parallel; I'm
      # not really sure right now. Might be tricky to avoid waiting
      # for other processes run by this program (could probably use
      # process groups for that?)
      @left.wait
      @right.wait
    end
  end
end
