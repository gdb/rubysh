require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class SubprocessTest < UnitTest
    before do
      Rubysh::Subprocess.any_instance.stubs(:hard_exit).with do |e|
        raise e if e
        true
      end
    end

    describe 'when running a command' do
      it 'calls exec with the expected arguments' do
        read_fd, write_fd = stub_pipe
        Kernel.expects(:exec).with do |*args|
          assert_equal([['cmd', 'cmd'], 'arg1', 'arg2'], args)
        end

        proc = Rubysh::Subprocess.new(['cmd', 'arg1', 'arg2'])
        proc.send(:open_exec_status)
        assert_raises(Rubysh::Error::UnreachableError) do
          proc.send(:do_run_child)
        end
      end

      describe 'with a Redirect' do
        it 'calls exec with the expected arguments' do
          runner = mock

          read_fd, write_fd = stub_pipe
          Kernel.expects(:exec).with do |*args|
            assert_equal([['cmd', 'cmd'], 'arg1', 'arg2'], args)
          end

          redirect = Rubysh::Redirect.new(2, '>', 1)
          redirect.expects(:apply!).with(runner)

          proc = Rubysh::Subprocess.new(['cmd', 'arg1', 'arg2'],
            nil, [redirect], [], runner)
          proc.send(:open_exec_status)
          assert_raises(Rubysh::Error::UnreachableError) do
            proc.send(:do_run_child)
          end
        end
      end
    end

    describe 'with a block' do
      it 'executes the block and then calls exit!' do
        called = false
        blk = Proc.new {called = true}

        proc = Rubysh::Subprocess.new([], blk)
        proc.send(:open_exec_status)
        proc.send(:do_run_child)

        assert(called, "Did not call the block")
      end
    end
  end
end
