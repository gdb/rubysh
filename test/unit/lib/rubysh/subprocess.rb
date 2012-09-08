require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class SubprocessTest < UnitTest
    describe 'when running a command' do
      it 'calls exec with the expected arguments' do
        read_fd, write_fd = stub_pipe
        Kernel.expects(:exec).with(['cmd', 'cmd'], 'arg1', 'arg2')

        proc = Rubysh::Subprocess.new(['cmd', 'arg1', 'arg2'])
        proc.send(:open_exec_status)
        assert_raises(Rubysh::Error::UnreachableError) do
          proc.send(:do_run_child)
        end
      end

      describe 'with a Redirect' do
        it 'calls exec with the expected arguments' do
          read_fd, write_fd = stub_pipe
          Kernel.expects(:exec).with(['cmd', 'cmd'], 'arg1', 'arg2')

          redirect = Rubysh::Redirect.new(2, '>', 1)
          redirect.expects(:apply!)

          proc = Rubysh::Subprocess.new(['cmd', 'arg1', 'arg2'],
            [redirect])
          proc.send(:open_exec_status)
          assert_raises(Rubysh::Error::UnreachableError) do
            proc.send(:do_run_child)
          end
        end
      end
    end
  end
end
