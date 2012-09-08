require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class SubprocessTest < UnitTest
    describe 'when running a command' do
      it 'calls exec with the expected arguments' do
        Kernel.expects(:exec).with(['cmd', 'cmd'], 'arg1', 'arg2')

        proc = Rubysh::Subprocess.new(['cmd', 'arg1', 'arg2'])
        assert_raises(Rubysh::Error::UnreachableError) do
          proc.send(:exec_program)
        end
      end
    end
  end
end
