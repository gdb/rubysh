require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class ReadTest < FunctionalTest
    describe 'when reading with :how => :partial' do
      it 'returns nil once the process is dead' do
        runner = Rubysh('ruby', '-e', 'puts "hi"', Rubysh.>).run_async

        # Pump stdout
        while runner.read(:how => :partial)
        end

        runner.wait
        assert_equal(nil, runner.read(:how => :partial))
      end
    end
  end
end
