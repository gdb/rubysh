require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class RedirectTest < UnitTest
    describe 'when redirecting 2>&1' do
      it 'correctly coerces when called with IO objects' do
        runner = mock
        stdout = stub(:fileno => 1)
        stderr = stub(:fileno => 2)

        stdout.stubs(:kind_of?).with(Integer).returns(false)
        stdout.stubs(:kind_of?).with(IO).returns(true)
        stderr.stubs(:kind_of?).with(String).returns(false)
        stderr.stubs(:kind_of?).with(IO).returns(true)

        # Due to stubbing
        IO.expects(:new).never

        redirect = Rubysh::Redirect.new(stderr, '>', stdout)
        redirect.expects(:dup2).once.with(1, 2)
        redirect.expects(:set_cloexec).once.with(2, false)

        redirect.apply!(runner)
      end
    end

    describe 'when redirecting an unopened FD 3>&1' do
      it 'applies dup2 as expected' do
        runner = mock
        stdout = stub(:fileno => 1)

        IO.expects(:new).with(1).returns(stdout)

        stdout = stub(:fileno => 1)

        redirect = Rubysh::Redirect.new(3, '>', 1)
        redirect.expects(:dup2).once.with(1, 3)
        redirect.expects(:set_cloexec).once.with(3, false)

        redirect.apply!(runner)
      end
    end
  end
end
