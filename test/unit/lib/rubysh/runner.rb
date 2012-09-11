require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class RunnerTest < UnitTest
    describe 'when setting up parallel_io' do
      it 'has the expected readers/writers' do
        read_fd, write_fd = stub_pipe
        command = Rubysh('ls', Rubysh.stderr > :stderr, Rubysh.stdin < :stdin)
        runner = Rubysh::Runner.new(command)

        assert_equal({read_fd => :stderr}, runner.readers)
        assert_equal({write_fd => :stdin}, runner.writers)
      end
    end
  end
end
