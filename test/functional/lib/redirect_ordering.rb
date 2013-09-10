require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class RedirectOrderingTest < FunctionalTest
    describe 'when redirecting within a pipeline' do
      it 'the internal redirect should win' do
        cmd = Rubysh('echo', 'whoops!', Rubysh.stdout > '/dev/null') | Rubysh('cat', Rubysh.stdout > :stdout)
        result = cmd.run

        output = result.read(:stdout)
        assert_equal('', output)
      end
    end
  end
end
