require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class RedirectTest < UnitTest
    describe 'when redirecting 2>&1' do
      it 'applies by calling stderr.reopen(stdout)' do
        stdout = mock
        stderr = mock(:reopen => stdout)
        IO.expects(:new).with(1).returns(stdout)
        IO.expects(:new).with(2).returns(stderr)
        redirect = Rubysh::Redirect.new(2, '>', 1)
        redirect.apply!
      end

      it 'correctly coerces when called with IO objects' do
        stdout = mock
        stderr = mock(:reopen => stdout)

        stdout.expects(:kind_of?).with(Integer).returns(false)
        stdout.expects(:kind_of?).with(IO).returns(true)
        stderr.expects(:kind_of?).with(String).returns(false)
        stderr.expects(:kind_of?).with(IO).returns(true)

        IO.expects(:new).never

        redirect = Rubysh::Redirect.new(stderr, '>', stdout)
        redirect.apply!
      end
    end

    describe 'when redirecting an unopened FD 3>&1' do
      it 'applies by using fcntl to dupfd' do
        stdout = mock
        stdout.expects(:fcntl).with(Fcntl::F_DUPFD, 3).returns(3)
        IO.expects(:new).with(1).returns(stdout)
        IO.expects(:new).with(3).raises(Errno::EBADF)

        redirect = Rubysh::Redirect.new(3, '>', 1)
        redirect.apply!
      end
    end
  end
end
