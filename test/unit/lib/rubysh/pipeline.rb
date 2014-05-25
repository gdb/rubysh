require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class PipelineTest < UnitTest
    describe 'when running a pipeline' do
      it 'correctly sets up extra redirects for the beginning of the pipeline' do
        subprocess = stub(:run => nil)
        Rubysh::Subprocess.stubs(:new => subprocess)

        command1 = Rubysh::Command.new(['ls', '/tmp'])
        command2 = Rubysh::Command.new(['grep', 'foo'])
        pipeline = Rubysh::Pipeline.new([command1, command2])

        runner = Rubysh::Runner.new(pipeline)
        runner.run_async

        extra_directives1 = runner.state(command1)[:extra_directives]

        assert_equal(1, extra_directives1.length)

        redirect = extra_directives1[0]

        assert_equal('>', redirect.direction)
        assert_equal(Rubysh::FD.new(1), redirect.source)
      end

      it 'correctly sets up extra redirects for the end of the pipeline' do
        subprocess = stub(:run => nil)
        Rubysh::Subprocess.stubs(:new => subprocess)

        command1 = Rubysh::Command.new(['ls', '/tmp'])
        command2 = Rubysh::Command.new(['grep', 'foo'])
        pipeline = Rubysh::Pipeline.new([command1, command2])

        runner = Rubysh::Runner.new(pipeline)
        runner.run_async

        extra_directives2 = runner.state(command2)[:extra_directives]

        assert_equal(1, extra_directives2.length)

        redirect = extra_directives2[0]

        assert_equal('<', redirect.direction)
        assert_equal(Rubysh::FD.new(0), redirect.source)
      end

      it 'correctly sets up extra redirects for the middle of the pipeline' do
        subprocess = stub(:run => nil)
        Rubysh::Subprocess.stubs(:new => subprocess)

        command1 = Rubysh::Command.new(['ls', '/tmp'])
        command2 = Rubysh::Command.new(['grep', 'foo'])
        command3 = Rubysh::Command.new(['cat'])
        pipeline = Rubysh::Pipeline.new([command1, command2, command3])

        runner = Rubysh::Runner.new(pipeline)
        runner.run_async

        extra_directives2 = runner.state(command2)[:extra_directives]

        assert_equal(2, extra_directives2.length)

        first_redirect = extra_directives2[0]
        assert_equal('<', first_redirect.direction)
        assert_equal(Rubysh::FD.new(0), first_redirect.source)

        second_redirect = extra_directives2[1]
        assert_equal('>', second_redirect.direction)
        assert_equal(Rubysh::FD.new(1), second_redirect.source)
      end

      it 'instantiates the subprocess objects with expected arguments' do
        subprocess = stub(:run => nil)
        Rubysh::Subprocess.expects(:new).once.with do |args, blk, directives, post_forks|
          args == ['ls', '/tmp'] &&
            directives.length == 1 &&
            directives[0].direction == '>' &&
            directives[0].source == Rubysh::FD.new(1)
        end.returns(subprocess)

        Rubysh::Subprocess.expects(:new).once.with do |args, blk, directives, post_forks|
          args == ['grep', 'foo'] &&
            directives.length == 2 &&
            directives[0].direction == '<' &&
            directives[0].source == Rubysh::FD.new(0) &&
            directives[1].direction == '>' &&
            directives[1].source == Rubysh::FD.new(1)
        end.returns(subprocess)

        Rubysh::Subprocess.expects(:new).once.with do |args, blk, directives, post_forks|
          args = ['cat'] &&
            directives.length == 1 &&
            directives[0].direction == '<' &&
            directives[0].source == Rubysh::FD.new(0)
        end.returns(subprocess)

        command1 = Rubysh::Command.new(['ls', '/tmp'])
        command2 = Rubysh::Command.new(['grep', 'foo'])
        command3 = Rubysh::Command.new(['cat'])
        pipeline = Rubysh::Pipeline.new([command1, command2, command3])

        runner = Rubysh::Runner.new(pipeline)
        runner.run_async
      end
    end
  end
end
