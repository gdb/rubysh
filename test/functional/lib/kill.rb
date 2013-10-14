require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class KillTest < FunctionalTest
    describe 'when killing' do
      it 'delivers a sigterm by default' do
        result = Rubysh.run_async('ruby', '-e', 'sleep 10', Rubysh.>)
        result.kill
        result.wait

        assert_equal(nil, result.exitstatus)
        assert_equal(Signal.list['TERM'], result.full_status.termsig)
      end

      it 'delivers the specified signal otherwise' do
        result = Rubysh.run_async('ruby', '-e', 'sleep 10', Rubysh.>)
        result.kill('KILL')
        result.wait

        assert_equal(nil, result.exitstatus)
        assert_equal(Signal.list['KILL'], result.full_status.termsig)
      end
    end
  end
end
